require File.join(File.dirname(__FILE__), 'user')

class Shortener
  module Server
    class Auth < Sinatra::Base

      dir = File.expand_path(File.dirname(__FILE__))
      set :root,          dir
      set :public_folder, File.join(dir, 'public')

      set(:signup) {|v| condition {$conf.allow_signup == v}}
      set(:has_views) {|v| condition {$conf.views == v}}

      helpers ShortServerHelpers

      helpers do
        def _response(views, api)
          if $conf.views && !(params[:format] == '.json')
            return views.call if views.is_a?(Proc) 
            redirect views
          else
            content_type :json
            views.is_a?(Proc) ? api.call.to_json : api.to_json
          end
        end
      end

      # this is our failure app, and this is where we handle that.
      post '/unauthenticated/?' do
        status 401
        _response(->{haml :'u/login'},
                  {message: "You are not authenticated. Pass your token!"})
      end

      #
      #  these handle view based authentication.
      #

      get('/u/login', has_views: true) { haml :'u/login'}

      get('/u/edit', has_views: true) do
        authorize!
        @action = '/api/v1/u/update'
        @user = env['warden'].user
        haml :'u/edit'
      end

      get('/u/signup', signup: true, has_views: true) do
        @action = '/api/v1/u/create'
        @user = User.new
        haml :'u/edit'
      end

      #
      # These are the api calls associated with authentiction
      #

      get '/api/v1/u/username_available.json' do
        {available: User.available?(params['user']['username'])}.to_json
      end

      post '/api/v1/u/create', signup: true do
        ret = if User.available?(params['user']['username'])
          u = User.new(params['user'])
          u.save
          env['warden'].set_user(u)
          ["#{base_url}/v/index", u]
        else
          ["#{base_url}/u/signup", {status: :fail, message: 'Username not available'}]
        end
        _response(*ret)
      end

      post '/api/v1/u/login.?:format?' do
        env['warden'].authenticate!#(:token)
        _url = session.delete(:REDIRECT_TO) || "#{$conf.shortener_url}/v/index"
        _response(_url, env['warden'].user)
      end

      get '/api/v1/u/logout.?:format?' do
        env['warden'].logout if env['warden'].authenticated?
        _response($conf.default_url, {message: 'l8er'})
      end

      post '/api/v1/u/update' do
        authorize!
        @user = env['warden'].user
        [:username, :email, :name].each do |attr|
          @user.send(:"#{attr}=", params['user'][attr.to_s])
        end
        unless params['user']['password'].nil? || params['user']['password'].empty?
          @user.password = params['user']['password']
        end
        @user.save
        _response("#{base_url}/v/index", @user)
      end

      post '/api/v1/u/reset_token.json' do
        authorize!
        user = env['warden'].user
        user.reset_token
        user.save
        env['warden'].set_user(user)
        content_type :json
        env['warden'].user.to_json
      end

      post '/api/v1/u/delete' do
        env['warden'].user.delete
        env['warden'].logout(env['warden'].config.default_scope)
        _response($conf.default_url, {message: "Miss you already"})
      end

    end
  end
end
