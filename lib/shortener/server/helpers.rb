class Shortener
  module Server
    module ShortServerHelpers

      def bad! message
        halt 412, {}, message
      end

      def nope!(message = 'No luck.')
        halt 404, {}, message
      end

      def base_url
        @base_url ||= "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
      end

      def clippy(text, bgcolor='#FFFFFF')
        html = <<-EOF
          <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
                  width="110"
                  height="25"
                  id="clippy" >
          <param name="movie" value="/flash/clippy.swf"/>
          <param name="allowScriptAccess" value="always" />
          <param name="quality" value="high" />
          <param name="scale" value="noscale" />
          <param NAME="FlashVars" value="text=#{text}">
          <param name="bgcolor" value="#{bgcolor}">
          <embed src="/flash/clippy.swf"
                 width="110"
                 height="14"
                 name="clippy"
                 quality="high"
                 allowScriptAccess="always"
                 type="application/x-shockwave-flash"
                 pluginspage="http://www.macromedia.com/go/getflashplayer"
                 FlashVars="text=#{text}"
                 bgcolor="#{bgcolor}"
          />
          </object>
        EOF
      end

      def ttl_display(ttl)
        if ttl == -1
          ret = 'expired'
        elsif ttl == nil
          ret = '&infin;'
        else
          ret = ttl
        end
        ret
      end

      def boxify_class(int, boxify_classes = '', nonbox_classes = '', other_classes = '')
        str = if @boxify
                "#{other_classes} #{boxify_classes}"
              else
                "#{other_classes} #{nonbox_classes}"
              end
        str = str + " offset#{int}" unless !int.nil? && @boxify
        str
      end

      def logged_in?
        return true unless $conf.authenticate?
        env['warden'].authenticated?
      end

      def available?(thing)
        return true unless $conf.authenticate?
        return true unless $conf.auth_route?(thing)
        return logged_in?
      end

      def authorize!(redir_url = '/u/login')
        return true unless $conf.authenticate?
        redirect redir_url unless env['warden'].authenticated?
      end

    end
  end
end

