require 'sinatra'
require 'redis'
require 'uri'
require 'haml'


dir = File.expand_path(File.dirname(__FILE__))
set :public_folder, File.join(dir, 'public')

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  $url_base = ENV['URL_BASE']
end

get '/' do
  redirect ENV['DEFAULT_URL'] || '/add'
end

get '/add' do
  haml :add
end

get '/:id' do
  url = $redis.get(params[:id])
  url.insert(0, 'http://') unless url[0..6] == 'http://'
  redirect url
end

post '/add' do
  fetch_shortened_url(params["shortener"]['url'])
end

def fetch_shortened_url(url)
  id = shorten(url)
  @url = "http://#{$url_base}/#{id}"
  haml :display
end

def shorten(url)
  begin
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;
    key  =  (0..4).map{ o[rand(o.length)]  }.join;
    puts "testing #{key}"
  end while !$redis.get(key).nil?
  $redis.set(key, url)
  key
end

