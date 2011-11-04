require 'sinatra'
require 'redis'
require 'uri'
require 'haml'
#require 'mongoid'


dir = File.expand_path(File.dirname(__FILE__))
set :public_folder, File.join(dir, 'public')

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
  redirect 'http://jakeplusbecca.us'
end

get '/add' do
  haml :add
end

get '/:id' do
  redirect $redis.get(params[:id])
end

post '/add' do
  id = gen_key
  p params, params["shortener"]["url"]
  $redis.set(id, params["shortener"]['url'])
  "http://j-b.us/#{id}"
end

def gen_key
  begin
    o =  [('a'..'z'),('A'..'Z')].map{|i| i.to_a}.flatten;
    string  =  (0..4).map{ o[rand(o.length)]  }.join;
    puts "testing #{string}"
  end while !$redis.get(string).nil?
  string
end
