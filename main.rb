require 'sinatra'
require 'redis'
require 'uri'
require 'json'
require 'haml'
require 'digest/sha1'


dir = File.expand_path(File.dirname(__FILE__))
set :public_folder, File.join(dir, 'public')

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  $default_url = ENV['DEFAULT_URL'] || '/index'
end

helpers do
  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
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
  $redis.keys('*:data').each do |key|
    p "  fetching data on #{key}"
    @shortens << $redis.hgetall(key)
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
  sha = $redis.get(params[:id])
  unless sha.nil?
    url = $redis.hget("#{sha}:data", 'url')
    $redis.hincrby("#{sha}:data", 'click-count', 1)
    url.insert(0, 'http://') unless url[0..6] == 'http://'
  else # we don't have that id
    url = $default_url
  end
  redirect url
end

post '/add' do
  @url = fetch_shortened_url(params["shortener"]['url'])
  haml :display
end

post '/add.json' do
  @url = fetch_shortened_url(params["shortener"]['url'])
  haml :display, :layout => false
end

def fetch_shortened_url(url)
  id = check_cache(url)
  id ||= shorten(url)
  "#{base_url}/#{id}"
end

def shorten(url)
  begin
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;
    key  =  (0..4).map{ o[rand(o.length)]  }.join;
    puts "testing #{key}"
  end while !$redis.get(key).nil?
  sha = Digest::SHA1.hexdigest(url)
  $redis.set(key, sha)
  $redis.hmset("#{sha}:data", 'shortened', key, 'url', url, 'set-count', 1)
  key
end

def check_cache(url)
  sha = Digest::SHA1.hexdigest(url)
  short = $redis.hgetall("#{sha}:data")
  unless short == {}
    $redis.hincrby("#{sha}:data", 'set-count', 1)
    return short['shortened']
  else
    return nil
  end
end

def delete_short(id)
  puts "puts deleting #{id}"
  puts sha = $redis.get(id)
  $redis.del "#{sha}:data"
  $redis.del id
end
