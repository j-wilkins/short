
class Shortener
  module Server
    class Brief

      class << self

        def all
          $redis.keys('data:*').map do |key|
            short = $redis.hgetall(key)
            puts "  url for #{key[-5..-1]} => #{short['url']}"
            short['expire'] = $redis.ttl(short['expire']) if short.has_key?('expire')
            short
          end
        end

        def find(id, params)
          sha = $redis.get(id)
          if sha.nil?   # => Short Not Found
            if (params[:captures].last == '.json')
              nope! "Short not found: #{id}"
            else
              puts "redirecting #{params[:captures].inspect} to default url"
              return $conf.default_url, :url
            end
          else         # => Short Found
            key = "data:#{sha}:#{id}"
            short = $redis.hgetall(key)
            not_expired = short.has_key?('expire') ? $redis.get(short['expire']) : true
            not_maxed = !(short['click_count'].to_i >= short['max_clicks'].to_i)
            short.has_key?('max_clicks') ? not_maxed : not_maxed = true
            if params[:captures].last == '.json'                                # => We just want JSON
              ret = short.merge({expired: not_expired.nil? , maxed: !not_maxed})
              return ret.to_json, :json
            else                                                                # => Redirect Me!
              $redis.hincrby(key, 'click_count', 1) if not_expired && not_maxed
              if not_expired
                unless short['s3'] == 'true' && !(short['type'] == 'download')
                  if not_maxed
                    puts "redirecting found short #{id} to #{short['url']}"
                    return short['url'], :url
                  end # => max clicks check
                else                                                            # => This is S3 content
                  puts "rendering view for s3 content. #{id} => #{short['url']}"
                  return short, :s3
                end # => it's S3 and needs displaying.
              end # => expired check
            end # => format
          end
          # =>    short was maxed or expired & not a JSON request
          return $conf.default_url, :url
        end

        def shorten(params)
          bad! 'Missing url.' unless url = params['url']
          bad! 'Bad URL' unless params['url'] =~ /(^http|^www)/
          url = "http://#{url}" unless /^http/i =~ url
          bad! 'Bad URL' unless (url = URI.parse(url)) && /^http/ =~ url.scheme

          %w(max_clicks expire desired_short allow_override).each do |k|
            params[k] = false if params[k].nil? || params[k].empty?
          end

          unless params['max_clicks'] || params['expire'] || params['desired_short']
            data = check_cache(url)
          end
          data ||= get_short_key(url, params)

          data
        end

        def delete(id)
          sha = $redis.get(id)
          unless sha.nil?
            $redis.multi do
              $redis.del "data:#{sha}:#{id}"
              $redis.del "expire:#{sha}:#{id}"
              $redis.del id
            end
            true
          else
            false
          end
        end

        def upload(params)
          bad! 'Missing content type.' unless type = params['type']
          fname = params['file_name'].gsub(' ', '+')
          url = "https://s3.amazonaws.com/#{$conf.s3_bucket}/#{$conf.s3_key_prefix}/#{fname}"
          data = {'s3' => true, 'extension' => File.extname(fname)[1..-1],
            'description' => params.delete('description'),
            'name' => params.delete('name'), 'type' => params.delete('type')}
          get_short_key(url, params, data)
        end

        private

        def get_short_key(url, options = {}, data = {})
          hsh_data = catch :stop_setting_up do
            unless options['desired_short']
              puts "    just generating a short"
              key = generate_short
            else
              do_check = $redis.get(options['desired_short'])
              key = if do_check.nil? || passes_desired_short_check(url, do_check, options)
                options['desired_short']
              else
                bad! 'Name is already taken. Use Allow override' unless options['allow_override'] == 'true'
                generate_short
              end
            end

            sha = Digest::SHA1.hexdigest(url.to_s)
            $redis.set(key, sha)

            hsh_data = data.merge('shortened' => key, 'url' => url, 'set_count' => 1)
            hsh_data['max_clicks'] = options['max_clicks'].to_i if options['max_clicks']

            if options['expire'] # set expire time if specified
              ttl = options['expire'].to_i
              ttl_key = "expire:#{sha}:#{key}"
              $redis.set(ttl_key, "#{sha}:#{key}")
              $redis.expire(ttl_key, ttl)
              hsh_data[:expire] = ttl_key
            end
            $redis.hmset("data:#{sha}:#{key}", *arrayify_hash(hsh_data))

            hsh_data
          end
        end

        def bad! message
          throw :halt, [412, {}, message]
        end

        def nope!(message = 'No luck.')
          throw :halt, [404, {}, message]
        end

        def generate_short
          begin
            o =  [('a'..'z'),('A'..'Z'),(0..9)].map{|i| i.to_a}.flatten;
            key  =  (0..4).map{ o[rand(o.length)]  }.join;
            puts "testing #{key}"
          end while !$redis.get(key).nil?
          key
        end

        def passes_desired_short_check(url, check, options)
          check_key = "data:#{check}:#{options['desired_short']}"
          prev_set = $redis.hgetall(check_key)

          return false if prev_set['expire']

          # if we don't expire or have max clicks and previously set key
          # doesn't expire or have max clicks we can go ahead and use it
          # without any further setup.
          unless options['expire'] || options['max_clicks']
            if (!prev_set['max_clicks'] && !prev_set['expire'] &&
              (prev_set['url'] == url.to_s))
              $redis.hincrby(check_key, 'set_count', 1)
              throw :stop_setting_up, prev_set
            end
          end

          return (prev_set['clicks'].to_i > prev_set['max_clicks'].to_i)
        end

        def check_cache(url)
          sha = Digest::SHA1.hexdigest(url.to_s)

          $redis.keys("data:#{sha}:*").each do |key|
            short = $redis.hgetall(key)
            unless short == {} || short['expire'] || short['max_clicks']
              $redis.hincrby(key, 'set_count', 1)
              return short
            end
          end
          nil
        end

        def arrayify_hash(hsh)
          hsh.keys.map {|k| [k, hsh[k]] }.flatten
        end
      end # => class << self

    end # => Shirt
  end # => Server
end # => Shortener
