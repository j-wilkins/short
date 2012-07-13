require 'uri'
require 'cgi'
require 'yaml'
require 'redis-namespace'

class Shortener
  # The class for storing Configuration Information
  class Configuration

    class << self
      def current
        @current_configuration ||= Configuration.new(conf_current_placeholder: nil)
      end
    end

    attr_accessor :options

    OPTIONS = [:SHORTENER_URL, :DEFAULT_URL, :REDISTOGO_URL, :S3_KEY_PREFIX,
      :S3_ACCESS_KEY_ID, :S3_SECRET_ACCESS_KEY, :S3_DEFAULT_ACL, :S3_BUCKET,
      :DOTFILE_PATH, :S3_ENABLED, :SHORTENER_NS, :REQUIRE_AUTH, :ALLOW_SIGNUP,
      :VIEWS, :USER_TOKEN]

    HEROKU_IGNORE = [:DOTFILE_PATH, :SHORTENER_URL, :REDISTOGO_URL, :REQUIRE_AUTH,
      :USER_TOKEN]

    AUTH_END_POINTS = [:username_available, :create, :login, :update, :reset_token]

    END_POINTS = [:add, :fetch, :upload, :index, :delete, :login, :reset_token]

    #store any paassed options and parse ~/.shortener if exists
    # priority goes dotfile < env < passed option
    def initialize(opts = Hash.new)
      # TODO check keys by calls opts.delete {|k| !OPTIONS.include?(k)
      unless opts.empty?
        opts.delete(:conf_current_placeholder)
        @options = Hash.new
        check_dotfile
        check_env
        @options = @options.merge!(opts)
        @options[:DEFAULT_URL] ||= '/index'
        if @options[:SHORTENER_URL] && @options[:SHORTENER_URL][-1] == '/'
          @options[:SHORTENER_URL] = @options[:SHORTENER_URL].chop
        end
        @options[:SHORTENER_NS] ||= :shortener
        @options[:VIEWS] = !(@options[:VIEWS] == false || @options[:VIEWS] == 'false')
        @options[:ALLOW_SIGNUP] = @options.has_key?(:ALLOW_SIGNUP)
        if @options[:REQUIRE_AUTH].is_a?(String) || @options[:REQUIRE_AUTH].is_a?(Symbol)
          @options[:REQUIRE_AUTH] = @options[:REQUIRE_AUTH].to_s.split(',').map do |auth|
            auth.upcase.to_sym
          end
        end
        @options[:REQUIRE_AUTH] ||= []
      else
        @options = Configuration.current.options
      end
    end

    # return a URI for an endpoint based on this configuration
    def uri_for(end_point, opts = nil)
      if END_POINTS.include?(end_point.to_sym)
        if end_point == :fetch
          path = opts.to_s
        else
          path = "api/v1/"
          path += 'u/' if AUTH_END_POINTS.include?(end_point)
          path += end_point.to_s
        end

        uri = URI.parse("#{@options[:SHORTENER_URL]}/#{path}.json")

        unless opts.nil? || end_point == :fetch
          query = opts.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&')
          uri.query = query
        end

      else
        raise "BAD ENDPOINT: #{end_point} is not a valid shortener end point."
      end

      uri
    end

    # return a string ENV's for command line use.
    def to_params
      ret = Array.new
      @options.each {|k,v| ret << "#{k}=#{v}" unless HEROKU_IGNORE.include?(k)}
      _ra = @options[:REQUIRE_AUTH].join(',')
      ret << "REQUIRE_AUTH=#{_ra}"
      ret.join(" ")
    end

    def to_json
      safe_options = @options.delete_if do |k|
        [:S3_SECRET_ACCESS_KEY, :S3_ACCESS_KEY_ID, :REDISTOGO_URL].include?(k)
      end
      safe_options.to_json
    end

    OPTIONS.each do |opt|
      next if [:REDISTOGO_URL, :S3_ENABLED, :REQUIRES_AUTH].include?(opt)
      method_name = opt.to_s.downcase.to_sym
      define_method "#{method_name}" do
        @options[opt]
      end
    end
    alias ns shortener_ns

    # a configured redis namespace instance
    def redis
      uri = self.redistogo_url
      _r = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
      Redis::Namespace.new(self.ns, redis: _r)
    end

    # return the URI for the redistogo url
    def redistogo_url
      begin
        URI.parse(@options[:REDISTOGO_URL])
      rescue Exception => boom
        puts "Error parsing redistogo_url: #{@options[:REDISTOGO_URL]}"
        puts "should probably be something like: redis://localhost:6379 if run locally"
        puts "if you're on Heroku, make sure you have the RedisToGo addon installed.\n\n"
        raise boom
      end
    end

    # return a boolean of the S3_ENABLED option
    def s3_enabled
      @options[:S3_ENABLED].to_s == 'true'
    end

    # are the necessary options present for S3 to work?
    def s3_configured
      ret = true
      [:S3_KEY_PREFIX, :S3_ACCESS_KEY_ID, :S3_SECRET_ACCESS_KEY,
        :S3_DEFAULT_ACL, :S3_BUCKET ].each do |k|
        ret = !@options[k].nil? unless ret == false
      end
      ret
    end

    # is S3 enabled and configured?
    def s3_available
      s3_enabled && s3_configured
    end

    # build an S3 policy.
    def s3_policy
      expiration_date = (Time.now + 36000).utc.strftime('%Y-%m-%dT%H:%M:%S.000Z') # 10.hours.from_now
      max_filesize = 2147483648 # 2.gigabyte
      policy = Base64.encode64(
        "{'expiration': '#{expiration_date}',
          'conditions': [
          {'bucket': '#{s3_bucket}'},
          ['starts-with', '$key', '#{s3_key_prefix}'],
          {'acl': '#{s3_default_acl}'},
          {'success_action_status': '201'},
          ['starts-with', '$Filename', ''],
          ['content-length-range', 0, #{max_filesize}]
          ]
          }"
      ).gsub(/\n|\r/, '')
    end

    # Sign an S3 policy
    def s3_signature(policy)
      signature = Base64.encode64(OpenSSL::HMAC.digest(
        OpenSSL::Digest::Digest.new('sha1'), s3_secret_access_key, policy)).gsub("\n","")
    end

    # a boolean indicating whether we should use authentication
    def authenticate?
      !(@options[:REQUIRE_AUTH] == [])
    end

    # check if this endpoint needs auth
    def auth_route?(url)
      url = url.path if url.respond_to?(:path)
      ep = url.split('/').last
      return false if ep.nil?
      ep.gsub!('.json', '')
      @options[:REQUIRE_AUTH].include?(ep.upcase.to_sym)
    end

    private

    # Parse the YAML dotfile if one exists
    def check_dotfile
      dotfile = @options[:DOTFILE_PATH] || File.join(ENV['HOME'], ".shortener")
      if File.exists?(dotfile)
        @options = @options.merge!(YAML::load_file(dotfile))
      end
    end

    # Check our environment for any overrides.
    def check_env
      OPTIONS.each do |opt|
        @options[opt] = ENV[opt.to_s] unless ENV[opt.to_s].nil?
      end
    end

  end
end
