require 'uri'
require 'yaml'

class Shortener
  # The class for storing Configuration Information
  class Configuration

    OPTIONS = [:SHORTENER_URL, :DEFAULT_URL, :REDISTOGO_URL, :S3_KEY_PREFIX, 
      :S3_ACCESS_KEY_ID, :S3_SECRET_ACCESS_KEY, :S3_DEFAULT_ACL, :S3_BUCKET, 
      :DOTFILE_PATH]

    END_POINTS = [:add, :fetch, :upload, :index]

    #store any paassed options and parse ~/.shortener if exists
    # priority goes dotfile < env < passed option
    def initialize(opts = Hash.new)
      # TODO check keys by calls opts.delete {|k| !OPTIONS.include?(k)
      @options = Hash.new
      check_dotfile
      check_env
      @options = @options.merge!(opts)
    end

    def uri_for(end_point)
      if END_POINTS.include?(end_point.to_sym)
        URI.parse("#{@options[:SHORTENER_URL]}/#{end_point}.json")
      else
        raise "BAD ENDPOINT: #{end_point} is not a valid shortener end point."
      end
    end

    OPTIONS.each do |opt|
      method_name = opt.to_s.downcase.to_sym
      define_method "#{method_name}" do
        @options[opt]
      end
    end

    private
      
      def check_dotfile
        dotfile = @options[:DOTFILE_PATH] || File.join(ENV['HOME'], ".shortener")
        if File.exists?(dotfile)
          p opts = YAML::load_file(dotfile)
          puts "single"
          p opts
          puts " //single"
          @options = @options.merge!(opts)
        end
      end

      def check_env
        OPTIONS.each do |opt|
          @options[opt] = ENV[opt.to_s] unless ENV[opt.to_s].nil?
        end
      end

  end
end
