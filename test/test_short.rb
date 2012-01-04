require 'minitest/autorun'
require_relative '../lib/shortener/short'

class TestShortenerShort < MiniTest::Unit::TestCase

  def setup
    @short = Shortener::Short.new('url' => 'http://google.com', 'shortened' => '12345',
        'set-count' => '12')
  end

  def test_instance_methods
    assert @short.shortened == '12345'
    assert @short.url == 'http://google.com'
    assert @short.set_count == 12
  end

  def test_brackets
    assert @short['shortened'] == '12345'
    assert @short[:shortened] == '12345'
    assert @short['set-count'] == 12
  end

  def test_defaults_ensure_keys
    short = Shortener.shorten('www.google.com')
    assert !short.shortened.nil?
    assert !short.url.nil?
    assert !short.set_count.nil?
    assert !short.click_count.nil?
  end

  def test_short_url
    assert @short.short_url == "#{@short.configuration.shortener_url}/#{@short.shortened}"
  end

  def test_uri
    assert @short.uri == URI.parse(@short.url)
  end

  def test_add
    short = Shortener::Short.shorten('www.google.com')
    assert short.is_a?(Shortener::Short)
    assert short.shortened.nil? == false
    assert short.url == 'http://www.google.com'
    assert short['success']
  end

  def test_index
    ind = Shortener::Short.index
    assert ind.is_a?(Array)
    assert ind.length >= 1
    assert ind.first.is_a?(Shortener::Short)
  end

  def test_fetch
    short = Shortener.shorten('www.google.com')
    short2 = Shortener::Short.fetch(short.shortened)
    assert short.shortened == short2.shortened
    short = Shortener.fetch('nope')
    assert short[:success] == false
  end

  def test_delete
    add = Shortener.shorten('www.google.com')
    del = Shortener.delete(add['shortened'])
    assert del['success']
  end
  
end
