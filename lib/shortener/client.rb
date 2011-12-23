dir = File.expand_path(File.dirname(__FILE__))
require 'net/http'
require 'json'
require File.join(dir, 'configuration')

class Shortener
  class Client

    attr_accessor :configuration

    def initialize(options = Hash.new)
      @configuration = Configuration.new(options)
    end

    # set a shortened url
    def shorten(url)
      opts = {'shortener' =>  {'url' => url}.to_json}
      response= request(:post, :add, opts)
      if response.is_a?(Net::HTTPOK)
        return JSON.parse(response.body)
      else
        raise "OH SHIT! #{response}"
      end
    end

    # get data for a short, including full url.
    def fetch(short)
      response = request(:get, :fetch, short)
      begin
        return JSON.parse(response)
      rescue Exception => boom
        raise "OH SHIT! #{boom}\n\n #{response}"
      end
    end

    # post a file to the configured s3 bucket and set a short.
    def upload(file)
    end

    # fetch data on multiple shorts
    def index(start = 0, stop = nil)
      response = request(:get, :index)
      begin
        return JSON.parse(response)
      rescue Exception => boom
        raise "OH SHIT! #{boom}\n\n #{response}"
      end
    end

    private

      # build a request based on configurations
      def request(type, end_point, args = nil)
        case type
        when :post
          Net::HTTP.post_form(@configuration.uri_for(end_point), args)
        when :get
          Net::HTTP.get(@configuration.uri_for(end_point, args))
        end
      end

  end # => Client
end # => Shortener
