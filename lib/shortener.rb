require 'uri'
require 'json'
require 'net/http'
dir = File.expand_path(File.dirname(__FILE__))

require File.join(dir, 'shortener', 'version')
require File.join(dir, 'shortener', 'configuration')
require File.join(dir, 'shortener', 'short')

class Shortener
  class << self; include Shortener::Short::ClassMethods; end
end
