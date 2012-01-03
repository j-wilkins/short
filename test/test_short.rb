require 'minitest/autorun'
require_relative '../lib/shortener/short'

class TestShortenerShort < MiniTest::Unit::TestCase

  def setup
    @short = Shortener::Short.new('url' => 'http://google.com', 'short' => '12345',
        'set-count' => '12')
  end

  def test_instance_methods
    assert @short.short == '12345'
    assert @short.url == 'http://google.com'
    assert @short.set_count == 12
  end

  def test_brackets
    assert @short['short'] == '12345'
    assert @short[:short] == '12345'
    assert @short['set-count'] == 12
  end

  def test_uri
    assert @short.uri == URI.parse(@short.url)
  end

  def test_add
    short = Shortener::Short.shorten('www.google.com')
    #short = @client.shorten('www.google.com')
    #assert short['success']
  end

  def test_index
    #ind = @client.index
    #assert ind.is_a?(Array)
  end

  def test_delete
    #add = @client.shorten('www.google.com')
    #del = @client.delete(add['short'])
    #assert del['success']
  end
  
end
