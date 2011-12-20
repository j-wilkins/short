require 'sinatra'
require 'redis-namespace'
require 'uri'
require 'json'
require 'haml'
require 'digest/sha1'
require 'base64'



module Shortener
  class Server < Sinatra::Base
    dir = File.expand_path(File.dirname(__FILE__))
    set :root,          File.join(dir, 'server')
    set :public_folder, File.join(dir, 'server', 'public')

    configure do
      uri = URI.parse(ENV["REDISTOGO_URL"])
      _redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      $redis = Redis::Namespace.new(:shortener, redis: _redis)
      $default_url = ENV['DEFAULT_URL'] || '/index'
      $s3_config = {
        bucket:            ENV['S3_BUCKET'],
        key_prefix:        ENV['S3_KEY_PREFIX'],
        default_acl:       ENV['S3_DEFAULT_ACL'],
        access_key_id:     ENV['S3_ACCESS_KEY_ID'],
        secret_access_key: ENV['S3_SECRET_ACCESS_KEY']
      }
    end

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
          id = check_cache(url)
        end
        id ||= shorten(url, params)

        "#{base_url}/#{id}"
      end

      def set_upload_short(params)
        bad! 'Missing content type.' unless type = params['type']
        key = generate_short
        fname = params['file_name'].gsub(' ', '+')
        sha = Digest::SHA1.hexdigest(fname)
        hash_key = "data:#{sha}:#{key}"
        url = "https://s3.amazonaws.com/#{$s3_config[:bucket]}/#{$s3_config[:key_prefix]}/#{fname}"
        ext = File.extname(fname)[1..-1]
        extras = ['url', url, 's3', true, 'shortened', key, 'extension', ext, 'set-count', 1]
        data = params.keys.map {|k| [k, params[k]] }.flatten.concat(extras)

        $redis.set(key, sha)
        $redis.hmset(hash_key, *data)

        "#{base_url}/#{key}"
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
                return options['desired-short']
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

        hsh_data = ['shortened', key, 'url', url, 'set-count', 1]
        hsh_data.concat(['max-clicks', options['max-clicks'].to_i]) if options['max-clicks']

        if options['expire'] # set expire time if specified
          ttl = options['expire'].to_i
          ttl_key = "expire:#{sha}:#{key}"
          $redis.set(ttl_key, "#{sha}:#{key}")
          $redis.expire(ttl_key, ttl)
          hsh_data.concat(['expire', ttl_key])
        end
        $redis.hmset("data:#{sha}:#{key}", *hsh_data)

        key
      end

      def check_cache(url)
        sha = Digest::SHA1.hexdigest(url.to_s)

        $redis.keys("data:#{sha}:*").each do |key|
          short = $redis.hgetall(key)
          unless short == {} || short['expire'] || short['max-clicks']
            $redis.hincrby(key, 'set-count', 1)
            return short['shortened']
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

      def s3_policy
        expiration_date = (Time.now + 36000).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z') # 10.hours.from_now
        max_filesize = 2147483648 # 2.gigabyte
        policy = Base64.encode64(
          "{'expiration': '#{expiration_date}',
            'conditions': [
            {'bucket': '#{$s3_config[:bucket]}'},
            ['starts-with', '$key', '#{$s3_config[:key_prefix]}'],
            {'acl': '#{$s3_config[:default_acl]}'},
            {'success_action_status': '201'},
            ['starts-with', '$Filename', ''],
            ['content-length-range', 0, #{max_filesize}]
            ]
            }"
        ).gsub(/\n|\r/, '')
      end

      def s3_signature(policy)
        signature = Base64.encode64(OpenSSL::HMAC.digest(
          OpenSSL::Digest::Digest.new('sha1'),
          $s3_config[:secret_access_key], policy)
        ).gsub("\n","")
      end

    end

    get '/' do
      redirect $default_url
    end

    get '/add' do
      haml :add
    end

    get '/index' do
      @shortens = Array.new
      $redis.keys('data:*').each do |key|
        short = $redis.hgetall(key)
        short['expire'] = $redis.ttl(short['expire']) if short.has_key?('expire')
        @shortens << short
        puts "  url for #{key[-5..-1]} => #{short['url']}"
      end
      haml :index
    end

    get '/delete/:id.:format' do |id, format|
      puts "#{id}, #{format}"
      delete_short(id)
      if format == 'json'
        content_type :json
        {success: true}.to_json
      else
        redirect :index
      end
    end

    get '/upload' do
      policy = s3_policy
      signature = s3_signature(policy)

      @post = {
        "key" => "#{$s3_config[:key_prefix]}/${filename}",
        "AWSAccessKeyId" => "#{$s3_config[:access_key_id]}",
        "acl" => "#{$s3_config[:default_acl]}",
        "policy" => "#{policy}",
        "signature" => "#{signature}",
        "success_action_status" => "201"
      }

      @upload_url = "http://#{$s3_config[:bucket]}.s3.amazonaws.com/"
      haml :upload
    end

    get '/:id' do
      id = params[:id]
      sha = $redis.get(id)
      unless sha.nil?
        key = "data:#{sha}:#{id}"
        short = $redis.hgetall(key)
        not_expired = short.has_key?('expire') ? $redis.get(short['expire']) : true
        if not_expired
          unless short['s3'] == 'true' && !(short['type'] == 'download')
            unless short.has_key?('max-clicks') && (short['click-count'].to_i >= short['max-clicks'].to_i)
              $redis.hincrby(key, 'click-count', 1)
              url = short['url']
            else
              #delete_short(id) # not sure if we want to delete these yet.
            end # => max clicks check
          else
            $redis.hincrby(key, 'click-count', 1)
            @short = short
            puts "rendering view for s3 content. #{id} => #{short['url']}"
            return haml(:"s3/#{short['type']}", layout: :'s3/layout')
          end
        end # => expired check
      end
      url ||= $default_url
      puts "redirecting #{id} to #{url}"
      redirect url
    end

    post '/upload.?:format?' do |format|
      content_type :json
      short = set_upload_short(params['shortener'])
      puts "set #{short} to #{params['shortener']['file_name']}"
      if format == 'json'
        {url: short}.to_json
      else
        redirect :index
      end
    end

    post '/add.?:format?' do |format|
      @url = set_or_fetch_url(params["shortener"])
      puts "set #{@url} to #{params['shortener']['url']}"
      if format == 'json'
        content_type :json
        {data: :success, html: haml(:display, :layout => false)}.to_json
      else
        haml :display
      end
    end

  end # => Server
end # => Shortener
