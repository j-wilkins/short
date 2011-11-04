require 'sinatra'
require 'redis'
#require 'mongoid'


dir = File.expand_path(File.dirname(__FILE__))
set :root, File.join(dir, 'app')
set :public_folder, File.join(dir, 'public')

configure do
  $redis = 
end

get '/' do
  redirect 'http://jakeplusbecca.us'
end

get '/:id' do

end

post '/add' do

end
