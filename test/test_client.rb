require 'minitest/autorun'
require_relative '../lib/shortener/client'

class TestShortenerClient < MiniTest::Unit::TestCase
  def setup
    @client = Shortener::Client.new
  end

  def test_add
    p @client.shorten('www.google.com')['short']
  end

end
