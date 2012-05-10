require 'uri'
require 'json'
require 'digest/sha1'
require 'base64'
require 'haml'

class Shortener
  module Server
    module Api
      class V1 < Sinatra::Base

        set(:s3_available) { |v| condition {$conf.s3_available == v} }
        set(:allow_signup) { |v| condition {$conf.allow_signup} }

        set :root, File.dirname(File.dirname(__FILE__))

        helpers ShortServerHelpers

        before do
          if $conf.auth_route?(env['PATH_INFO']) && 
            !env['warden'].authenticated?(:token) &&
            !env['warden'].authenticate!(:token)
            halt 401, {}, "Not Authorized, specify your auth token."
          end
        end if $conf.authenticate?

        get '/' do
          redirect $conf.default_url
        end

        get '/api/v1/index.?:format?' do
          Brief.all.to_json
        end

        post '/api/v1/upload.?:format?' do
          @data = Brief.upload(params['shortener'])
          puts "set #{@data['shortened']} to #{params['shortener']['file_name']}"
          @url = "#{base_url}/#{@data['shortened']}"
          content_type :json
          @data.merge({html: haml(:display, layout: false)}).to_json
        end

        post '/api/v1/add.?:format?' do
          @data = Brief.shorten(params["shortener"])
          @url = "#{base_url}/#{@data['shortened']}"
          puts "set #{@url} to #{params['shortener']['url']}"
          content_type :json
          @data.merge({success: true, html: haml(:display, :layout => false)}).to_json
        end

        post '/api/v1/delete.?:format?' do 
          status = Brief.delete(params['id'])
          nope! "Short not found: #{params['id']}" if status == false
          puts " - deleted short id: #{params['id']}"
          content_type :json
          {success: status, shortened: params['id']}.to_json
        end

        get '/api/v1/config.?:format?' do
          $conf.to_json
        end

        #get '/:id.?:format?' do
        get %r{\/([a-z0-9]{3,})(\.[a-z]{3,}){0,1}}i do
          id = params[:captures].first
          @short, type = Brief.find(id, params)
          redirect @short if type == :url
          return haml(:"s3/#{@short['type']}", layout: :'s3/layout') if type == :s3
          content_type :json
          @short
        end

      end
    end
  end
end
