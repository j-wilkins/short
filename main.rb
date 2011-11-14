require 'sinatra'
require 'redis-namespace'
require 'uri'
require 'json'
require 'haml'
require 'digest/sha1'


dir = File.expand_path(File.dirname(__FILE__))
set :public_folder, File.join(dir, 'public')

configure do
  if ENV['RACK_ENV'] == 'production'
    uri = URI.parse(ENV["REDISTOGO_URL"])
    _redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    _redis = Redis.new
  end
  $redis = Redis::Namespace.new(:shortener, redis: _redis)
  $default_url = ENV['DEFAULT_URL'] || '/index'
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

    p params
    unless params['max-clicks'] || params['expire'] || params['desired-short']
      id = check_cache(url)
    end
    id ||= shorten(url, params)
    p id

    "#{base_url}/#{id}"
  end

  def shorten(url, options = {})

    puts "shortening"
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
          p prev_set
          puts "options not present. #{prev_set['url']} => #{url}"
          p (prev_set['url'] == url.to_s)
          if (!prev_set['max-clicks'] && !prev_set['expire'] && 
            (prev_set['url'] == url.to_s)) # TODO make sure this equality check works.
            puts "made it in if"
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
    puts "puts deleting #{id}"
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
    p "  fetching data on #{key}"
    short = $redis.hgetall(key)
    short['expire'] = $redis.ttl(short['expire']) if short.has_key?('expire')
    @shortens << short
  end
  p @shortens
  haml :index
end

get '/delete/:id.json' do
  delete_short(params[:id])
  content_type :json
  {success: true}.to_json
end

get '/delete/:id' do
  delete_short(params[:id])
  redirect :index
end

get '/:id' do
  id = params[:id]
  sha = $redis.get(id)
  unless sha.nil?
    key = "data:#{sha}:#{id}"
    short = $redis.hgetall(key)
    not_expired = short.has_key?('expire') ? $redis.get(short['expire']) : true
    if not_expired
      unless short.has_key?('max-clicks') && (short['click-count'].to_i >= short['max-clicks'].to_i)
        $redis.hincrby(key, 'click-count', 1)
        url = short['url']
      else
        #delete_short(id) # not sure if we want to delete these yet.
      end # => max clicks check
    end # => expired check
  end
  url ||= $default_url
  redirect url
end

post '/add' do
  @url = set_or_fetch_url(params["shortener"])
  haml :display
end

post '/add.json' do
  @url = set_or_fetch_url(params["shortener"])
  p @url
  haml :display, :layout => false
end
