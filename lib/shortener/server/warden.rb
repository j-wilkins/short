
Warden::Manager.serialize_into_session{|user| user.token }
Warden::Manager.serialize_from_session{|token| User.get_by_token(token) }

Warden::Manager.before_failure do |env,opts|
  env['REQUEST_METHOD'] = "POST"
end

Warden::Strategies.add(:password) do
  def valid?
    params['user']["username"] || params['user']["password"]
  end

  def authenticate!
    u = User.authenticate!(params['user']["username"], params['user']["password"])
    u ? success!(u) : fail!('Could not log in')
  end
end

Warden::Strategies.add(:token) do
  def valid?
    params.has_key?('token')
  end

  def authenticate!
    u = User.get_by_token(params['token'])
    u ? success!(u) : fail!('Could not log in')
  end
end
