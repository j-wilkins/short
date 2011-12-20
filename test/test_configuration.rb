require 'minitest/autorun'
require_relative '../lib/shortener/configuration'

class TestShortenerConfiguration < MiniTest::Unit::TestCase

  def setup
    @conf = Shortener::Configuration.new(:SHORTENER_URL => 'localhost:4567')
  end

  def test_pass_options
    @conf = Shortener::Configuration.new(:SHORTENER_URL => 'fuckoff')
    assert @conf.is_a?(Shortener::Configuration)
    assert @conf.shortener_url == 'fuckoff'
    p @conf.default_url
  end

  def test_uri_for
    test = URI.parse("#{@conf.shortener_url}/add.json")
    p @conf, @conf.shortener_url, @conf.uri_for(:add)
    assert @conf.uri_for(:add) == test
  end

end
