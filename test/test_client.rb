require 'minitest/autorun'
require_relative '../lib/shortener/client'

class TestShortenerClient < MiniTest::Unit::TestCase

  def setup
    @client = Shortener::Client.new
  end

  def test_add
    short = @client.shorten('www.google.com')
    assert short['success']
  end

  def test_index
    ind = @client.index
    assert ind.is_a?(Array)
  end

  def test_delete
    add = @client.shorten('www.google.com')
    del = @client.delete(add['short'])
    assert del['success']
  end

end
