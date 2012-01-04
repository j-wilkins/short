require 'sinatra'
require 'redis-namespace'
require 'uri'
require 'json'
require 'haml'
require 'digest/sha1'
require 'base64'
require File.join(File.dirname(__FILE__), 'configuration')



class Shortener
  class Server < Sinatra::Base
    dir = File.expand_path(File.dirname(__FILE__))
    set :root,          File.join(dir, 'server')
    set :public_folder, File.join(dir, 'server', 'public')

    configure do
      $conf = Shortener::Configuration.new
      uri = $conf.redistogo_url
      _redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      $redis = Redis::Namespace.new(:shortener, redis: _redis)
    end

    set(:s3_available) {|v| condition {$conf.s3_available == v}}

    helpers do

      def bad! message
        halt 412, {}, message
      end

      def nope!
        halt 404, {}, "No luck."
      end

      def base_url
        @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
      end

      def clippy(text, bgcolor='#FFFFFF')
        html = <<-EOF
          <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
                  width="110"
                  height="25"
                  id="clippy" >
          <param name="movie" value="/flash/clippy.swf"/>
          <param name="allowScriptAccess" value="always" />
          <param name="quality" value="high" />
          <param name="scale" value="noscale" />
          <param NAME="FlashVars" value="text=#{text}">
          <param name="bgcolor" value="#{bgcolor}">
          <embed src="/flash/clippy.swf"
                 width="110"
                 height="14"
                 name="clippy"
                 quality="high"
                 allowScriptAccess="always"
                 type="application/x-shockwave-flash"
                 pluginspage="http://www.macromedia.com/go/getflashplayer"
                 FlashVars="text=#{text}"
                 bgcolor="#{bgcolor}"
          />
          </object>
        EOF
      end

      def set_or_fetch_url(params)
        bad! 'Missing url.' unless url = params['url']
        url = "http://#{url}" unless /^http/i =~ url
        bad! 'Malformed url.' unless (url = URI.parse(url)) && /^http/ =~ url.scheme

        %w(max-clicks expire desired-short allow-override).each do |k|
          params[k] = false if params[k].nil? || params[k].empty?
        end

        unless params['max-clicks'] || params['expire'] || params['desired-short']
          data = check_cache(url)
        end
        data ||= shorten(url, params)

        data
      end

      def set_upload_short(params)
        bad! 'Missing content type.' unless type = params['type']
        key = generate_short
        fname = params['file_name'].gsub(' ', '+')
        sha = Digest::SHA1.hexdigest(fname)
        hash_key = "data:#{sha}:#{key}"
        url = "https://s3.amazonaws.com/#{$conf.s3_bucket}/#{$conf.s3_key_prefix}/#{fname}"
        ext = File.extname(fname)[1..-1]
        data = {'url' => url, 's3' => true, 'shortened' => key, 
          'extension' => ext, 'set-count' => 1}
        data = params.merge(data)

        $redis.set(key, sha)
        $redis.hmset(hash_key, *arrayify_hash(data))

        data
      end

      def shorten(url, options = {})

        unless options['desired-short']
          key = generate_short
        else
          check = $redis.get(options['desired-short'])
          if check  # it's already taken
            check_key = "data:#{check}:#{options['desired-short']}"
            prev_set = $redis.hgetall(check_key)

            # if we don't expire or have max clicks and previously set key
            # doesn't expire or have max clicks we can go ahead and use it
            # without any further setup.
            unless options['expire'] || options['max-clicks']
              if (!prev_set['max-clicks'] && !prev_set['expire'] &&
                (prev_set['url'] == url.to_s))
                $redis.hincrby(check_key, 'set-count', 1)
                return prev_set
              end
            end

            if prev_set['max-clicks'].to_i < prev_set['clicks'].to_i
              # previous key is no longer valid, we can assign to it
              key = options['desired-short']
            else
              bad! 'Name is already taken. Use Allow override' unless options['allow-override'] == 'true'
              key = generate_short
            end

          else
            key = options['desired-short']
          end
        end

        sha = Digest::SHA1.hexdigest(url.to_s)
        $redis.set(key, sha)

        hsh_data = {'shortened' => key, 'url' => url, 'set-count' => 1}
        hsh_data['max-clicks'] = options['max-clicks'].to_i if options['max-clicks']

        if options['expire'] # set expire time if specified
          ttl = options['expire'].to_i
          ttl_key = "expire:#{sha}:#{key}"
          $redis.set(ttl_key, "#{sha}:#{key}")
          $redis.expire(ttl_key, ttl)
          hsh_data[:expire] = ttl_key
        end
        $redis.hmset("data:#{sha}:#{key}", *arrayify_hash(hsh_data))

        hsh_data
      end

      def check_cache(url)
        sha = Digest::SHA1.hexdigest(url.to_s)

        $redis.keys("data:#{sha}:*").each do |key|
          short = $redis.hgetall(key)
          unless short == {} || short['expire'] || short['max-clicks']
            $redis.hincrby(key, 'set-count', 1)
            return short
          end
        end
        nil
      end

      def delete_short(id)
        puts "deleting #{id}"
        puts sha = $redis.get(id)
        $redis.multi do
          $redis.del "data:#{sha}:#{id}"
          $redis.del "expire:#{sha}:#{id}"
          $redis.del id
        end
      end

      def generate_short
        begin
          o =  [('a'..'z'),('A'..'Z'),(0..9)].map{|i| i.to_a}.flatten;
          key  =  (0..4).map{ o[rand(o.length)]  }.join;
          puts "testing #{key}"
        end while !$redis.get(key).nil?
        key
      end

      def ttl_display(ttl)
        if ttl == -1
          ret = 'expired'
        elsif ttl == nil
          ret = '&infin;'
        else
          ret = ttl
        end
        ret
      end

      def arrayify_hash(hsh)
        hsh.keys.map {|k| [k, hsh[k]] }.flatten
      end

    end

    before do
      params
    end

    get '/' do
      redirect $conf.default_url
    end

    get '/add' do
      haml :add
    end

    get '/index.?:format?' do
      @shortens = Array.new
      $redis.keys('data:*').each do |key|
        short = $redis.hgetall(key)
        short['expire'] = $redis.ttl(short['expire']) if short.has_key?('expire')
        @shortens << short
        puts "  url for #{key[-5..-1]} => #{short['url']}"
      end
      if params[:format] == 'json'
        content_type :json
        return @shortens.to_json
      end
      haml :index
    end

    get '/delete/:id.:format' do |id, format|
      delete_short(id)
      if format == 'json'
        content_type :json
        {success: true, shortened: id}.to_json
      else
        redirect :index
      end
    end

    get '/upload', s3_available: true do
      policy = $conf.s3_policy
      signature = $conf.s3_signature(policy)

      @post = {
        "key" => "#{$conf.s3_key_prefix}/${filename}",
        "AWSAccessKeyId" => "#{$conf.s3_access_key_id}",
        "acl" => "#{$conf.s3_default_acl}",
        "policy" => "#{policy}",
        "signature" => "#{signature}",
        "success_action_status" => "201"
      }

      @upload_url = "http://#{$conf.s3_bucket}.s3.amazonaws.com/"
      haml :upload
    end

    #get '/:id.?:format?' do
    get %r{\/([a-z0-9]{3,})(\.[a-z]{3,}){0,1}}i do
      id = params[:captures].first
      sha = $redis.get(id)
      if sha.nil?
        if (params[:captures].last == '.json')
          content_type :json
          return {success: false, message: 'Short not found'}.to_json
        else
          puts "redirecting to default url"
          redirect $conf.default_url
        end
      else
        key = "data:#{sha}:#{id}"
        short = $redis.hgetall(key)
        not_expired = short.has_key?('expire') ? $redis.get(short['expire']) : true
        not_maxed = !(short['click-count'].to_i >= short['max-clicks'].to_i)
        short.has_key?('max-clicks') ? not_maxed : not_maxed = true
        if params[:captures].last == '.json'
          ret = short.merge({expired: not_expired.nil? , maxed: !not_maxed})
          content_type :json
          return ret.to_json
        else
          $redis.hincrby(key, 'click-count', 1) if not_expired && not_maxed
          if not_expired
            unless short['s3'] == 'true' && !(short['type'] == 'download')
              if not_maxed
                puts "redirecting #{id} to #{url}"
                redirect short['url']
              end # => max clicks check
            else
              @short = short
              puts "rendering view for s3 content. #{id} => #{short['url']}"
              return haml(:"s3/#{short['type']}", layout: :'s3/layout')
            end # => it's S3 and needs displaying.
          end # => expired check
        end # => format
      end
      puts "redirecting to default url"
      redirect $conf.default_url
    end

    post '/upload.?:format?' do |format|
      @data = set_upload_short(params['shortener'])
      puts "set #{@data['shortened']} to #{params['shortener']['file_name']}"
      @url = "#{base_url}/#{@data['shortened']}"
      if format == 'json'
        content_type :json
        @data.merge({html: haml(:display, layout: false)}).to_json
      else
        redirect :index
      end
    end

    post '/add.?:format?' do |format|
      begin
        # TODO figure out why the fuck these are parsing from Net::HTTP
        params['shortener'] = JSON.parse(params['shortener']) if params['shortener'].is_a?(String)
      rescue Exception => boom
        # essentally, params = params
      end

      @data = set_or_fetch_url(params["shortener"])
      @url = "#{base_url}/#{@data['shortened']}"
      puts "set #{@url} to #{params['shortener']['url']}"
      if format == 'json'
        content_type :json
        @data.merge({success: true, html: haml(:display, :layout => false)}).to_json
      else
        haml :display
      end
    end

  end # => Server
end # => Shortener
