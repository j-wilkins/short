# much of this code copied directly from
#   https://github.com/antirez/lamernews/blob/master/app.rb

require File.join(File.dirname(__FILE__), 'pbkdf2')

class User

  ATTRS = [:id, :name, :email]

  attr_accessor *ATTRS
  attr_reader :password, :salt, :username, :token

  def self.authenticate!(username, password)
    user = get_by_username(username)
    return false unless user
    ((hash_password(password, user.salt)) == user.password) ? user : false
  end

  def self.get_by_id(id)
    attrs = $redis.hgetall("user:#{id}")
    return nil if attrs.empty?
    attrs['prehashed_password'] = attrs.delete('password')
    u = User.new(attrs)
  end

  def self.get_by_username(username)
    _id = $redis.get("username.to.id:#{username.downcase}")
    return nil unless _id
    get_by_id(_id)
  end

  def self.get_by_token(token)
    _id = $redis.get("auth:#{token}")
    return nil unless _id
    get_by_id(_id)
  end

  def self.available?(username)
    $redis.get("username.to.id:#{username.downcase}").nil?
  end

  def initialize(attrs = {})
    ATTRS.each do |attr|
      self.instance_variable_set(:"@#{attr}", attrs[attr.to_s])
    end
    @salt = attrs['salt'] || get_rand
    @token = attrs['token'] || get_rand
    @username = attrs['username']
    @password = User.hash_password(attrs['password'], @salt) if attrs['password']
    @password = attrs['prehashed_password'] if attrs['prehashed_password']
  end

  def password=(string)
    @password =  User.hash_password(string, @salt)
  end

  def username=(string)
    unless string == @username
      @prev_username = self.username if @prev_username.nil?
      @username = string
    end
  end

  def token=(string)
    unless string == @token
      @prev_token = self.token if @prev_token.nil?
      @token = string
    end
  end

  def reset_token
    self.token = get_rand
  end

  def save
    self.id = $redis.incr("users.count") unless id
    $redis.hmset("user:#{id}",
      "id", id,
      "name", name,
      "username", username,
      "salt", salt,
      "password", password,
      "email", email,
      "token", token)
    if @prev_username
      puts "deleting prev_username #{@prev_username}"
      $redis.del("username.to.id:#{@prev_username.downcase}")
      @prev_username = nil
    end
    if @prev_token
      $redis.del("auth:#{@prev_token}")
      @prev_token = nil
    end
    $redis.set("username.to.id:#{username.downcase}", id)
    $redis.set("auth:#{token}", id)
    return id, nil
  end

  def delete
    $redis.del("username.to.id:#{username.downcase}")
    $redis.del("user:#{id}")
    $redis.del("auth:#{token}")
    true
  end

  def to_json
    {id: id, username: username, name: name, email: email, token: token}.to_json
  end

  private

  # Return the hex representation of an unguessable 160 bit random number.
  def get_rand
    rand = "";
    File.open("/dev/urandom").read(20).each_byte{|x| rand << sprintf("%02x",x)}
    rand
  end

  # Turn the password into an hashed one, using PBKDF2 with HMAC-SHA1
  # and 160 bit output.
  def self.hash_password(password, salt)
    p = PBKDF2.new do |p|
      p.iterations = 1000
      p.password = password
      p.salt = salt
      p.key_length = 160/8
    end
    p.hex_string
  end

end
