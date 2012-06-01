
class Shortener
  class Short

    SHORT_KEYS = [:url, :shortened, :type, :ext, :s3, :'click-count', :'max-count',
      :'set-count', :'expire-time', :sha]

    attr_reader :data

    module ClassMethods

      # set a shortened url
      def shorten(url, conf = nil)
        opts = {"shortener[url]" => "#{url}"}
        response = request(:post, :add, conf, opts)
        if response.is_a?(Net::HTTPOK)
          return Short.new(response.body, conf)
        else
          raise "OH SHIT! #{response}"
        end
      end

      # get data for a short, including full url.
      def fetch(short, conf = nil)
        response = request(:get, :fetch, conf, short)
        Short.new(response.body, conf)
      end

      # post a file to the configured s3 bucket and set a short.
      def upload(file)
      end

      # fetch data on multiple shorts
      def index(start = 0, stop = nil, conf = nil)
        response = request(:get, :index, conf)
        data = JSON.parse(response.body)
        shorts = data.map {|sh| Short.new(sh, conf)}
        shorts
      end

      # delete a short
      def delete(short, conf = nil)
        response = request(:post, :delete, conf, {id: short})
        Short.new(response.body, conf)
      end

      # build a request based on configurations
      def request(type, end_point, conf = nil, args = nil)
        config = conf || Shortener::Configuration.current
        response = case type
        when :post
          Net::HTTP.post_form(config.uri_for(end_point), args)
        when :get
          Net::HTTP.get_response(config.uri_for(end_point, args))
        end
        raise NetworkException.new(response.body) if response.kind_of?(Net::HTTPClientError)
        response
      end

    end # => ClassMethods

    class << self; include ClassMethods; end

    # Set up this short. Will:
    # * store the configuration if necessary
    # * parse JSON if short is JSON
    # * symbolize the shorts keys
    # * turn string numbers in to actual numbers.
    def initialize(short, conf = nil)
      @configuration = conf unless conf.nil?
      short = parse_return(short) unless short.is_a?(Hash)
      @data = symbolize_keys(short)
      normalize_data
    end

    # the configuration that this short will use.
    def configuration
      @configuation.nil? ? Shortener::Configuration.current : @configuration
    end

    # an alternative way to fetch stuff from @data
    def [](key)
      @data[key.to_sym]
    end

    # return a URI of the URL
    def uri
      URI.parse(url)
    end

    # shortened combined with config#shortener_url
    def short_url
      "#{configuration.shortener_url}/#{shortened}"
    end

    # a URI of short url.
    def short_uri
      URI.parse(short_url)
    end

    # allow the updating of a field. considering an arity like:
    # update(hsh_of_fields_with_values)
    # and it will create a POST request to send server side.
    def update
      #TODO
    end

    SHORT_KEYS.each do |key|
      name = key.to_s.include?('-') ? key.to_s.gsub('-', '_').to_sym : key
      define_method name do
        @data[key]
      end
    end

    def pretty_print

    end

    private

      # used to turn the hash keys of the data hash in to symbols.
      def symbolize_keys(hash)
        ret = Hash.new
        hash.each do |k,v|
          ret[k.to_sym] = v
        end
        ret
      end

      # turn string numbers in to actual numbers.
      def normalize_data
        [:'click-count', :'max-count', :'set-count'].each do |k|
          @data[k] = @data[k].to_i
        end
        @data[:'click-count'] ||= 0
      end

      # parse JSON safely.
      def parse_return(json)
        begin
          return JSON.parse(json)
        rescue Exception => boom
          raise "OH SHIT! #{boom}\n\n #{json}"
        end
      end

  end
end
require_relative '../shortener'
