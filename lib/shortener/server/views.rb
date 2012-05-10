require 'haml'

class Shortener
  module Server
    class Views < Sinatra::Base

      dir = File.expand_path(File.dirname(__FILE__))
      set :root,          dir
      set :public_folder, File.join(dir, 'public')

      set(:s3_available) {|v| condition {$conf.s3_available == v}}

      helpers ShortServerHelpers

      before do
        if $conf.auth_route?(env['PATH_INFO']) && !env['warden'].authenticated?
          session['REDIRECT_TO'] = env['PATH_INFO']
          redirect('/u/login')
        end
      end if $conf.authenticate?

      get('/index') { redirect "/v/index" }

      get '/v/index' do
        @shortens = Brief.all
        haml :index
      end

      get '/v/add' do
        @boxify = !params['boxify'].nil?
        haml :add, layout: !@boxify
      end

      get '/v/upload', s3_available: true do
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
        @boxify = !params['boxify'].nil?
        haml :upload, layout: !@boxify
      end

    end # => Views
  end # => Server
end # => Shortener
