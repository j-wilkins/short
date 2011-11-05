require 'sinatra'
require 'redis'
require 'uri'
require 'haml'
require 'digest/sha1'


dir = File.expand_path(File.dirname(__FILE__))
set :public_folder, File.join(dir, 'public')

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
  redirect ENV['DEFAULT_URL'] || '/index'
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

get '/:id' do
  sha = $redis.get(params[:id])
  url = $redis.hget("#{sha}:data", 'url')
  $redis.hincrby("#{sha}:data", 'click-count', 1)
  url.insert(0, 'http://') unless url[0..6] == 'http://'
  redirect url
end

post '/add' do
  fetch_shortened_url(params["shortener"]['url'])
end

def fetch_shortened_url(url)
  id = check_cache(url)
  id ||= shorten(url)
  "http://j-b.us/#{id}"
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
