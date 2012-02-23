
namespace :short do

  namespace :heroku do
    $gem_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))

    def gem_file(f)
      #ret = args.map {|f| File.join($gem_dir, f)}.join(" ")
      File.join($gem_dir, f.to_s)
    end

    def _file(f)
      fs = $existing_repo ? [f.to_s] : ['shortener-heroku', f.to_s]
      File.join(Dir.pwd, *fs)
    end

    def _ep(f)
      beginning_int = case f.split('/')[-3]
      when 'shortener'
        puts "************short" if ENV['VVERBOSE']
        -2
      when 'public', 'views', 's3'
        puts "************public || s3" if ENV['VVERBOSE']
        -4
      when 'skin'
        puts "************views" if ENV['VVERBOSE']
        -5
      else
        puts "************else #{f.split('/')[-3]}" if ENV['VVERBOSE']
        -3
      end
      end_point = f.split('/')[beginning_int..-1].join('/')
    end

    def _l(action, start, nd = nil)
      if ENV['VERBOSE']
        msg = "#{action}: #{start} "
        msg += "=> #{nd}" unless nd.nil?
        puts msg
      end
    end

    def recursively_remove_files(dir)
      dirs = Array.new
      Dir[File.join(dir, '*')].each do |f|
        next if f =~ /^(\.|\..*)/
        if File.directory?(f)
          if Dir.entries(f).empty?
            _l(:removing_dir, f)
            FileUtils.rmdir(f)
          else
            dirs << f
            recursively_remove_files(f)
          end
        else
          _l(:removing, f)
          FileUtils.rm(f)
        end
      end
      _l(:removing_dir, dirs)
      FileUtils.rmdir(dirs)
    end

    desc "Build a Heroku Ready Git repo"
    task :build do
      FileUtils.mkdir(File.join(Dir.pwd, 'shortener-heroku')) unless $existing_repo
      [:'server', :'server/public', :'server/views',
       :'server/views/s3', :'server/public/flash',
       :'server/public/skin', :'server/public/images',
       :'server/public/skin/blue.monday'].each do |f|
        unless File.exist?(_file(f))
          puts "creating #{_file(f)}" if ENV['VERBOSE']
          FileUtils.mkdir(_file(f))
        end
      end

      ['server', 'server/public', 'server/views', :'server/views/s3',
       :'server/public/flash', :'server/public/images', :'server/public/skin',
       :'server/public/skin/blue.monday'].each do |end_point|
        Dir["#{$gem_dir}/#{end_point}/**"].each do |f|
          next if File.directory?(f)
          end_point = _file(:"#{_ep(f)}")
          _l(:copying, f, end_point)
          FileUtils.cp(f, end_point)
        end
      end
      _s, _e = gem_file('server.rb'), _file(:'main.rb')
      _l(:copying, _s, _e)
      FileUtils.cp(_s, _e)
      _s, _e = gem_file('configuration.rb'), _file(:'configuration.rb')
      _l(:copying, _s, _e)
      FileUtils.cp(_s, _e)
      _s, _e = _file('server/config.ru.template'), _file(:'config.ru')
      _l(:renaming, _s, _e)
      FileUtils.mv(_s, _e)
      _s, _e = _file('server/Gemfile'), _file(:'Gemfile')
      _l(:renaming, _s, _e)
      FileUtils.mv(_s, _e)
      _s, _e = _file(:'server/Gemfile.lock'), _file(:'Gemfile.lock')
      _l(:renaming, _s, _e)
      FileUtils.mv(_s, _e)
      File.open(_file(:Rakefile), 'w+') do |f|
        f.puts "require 'shortener/tasks/heroku'"
      end
    end

    desc "initialize the Git repo"
    task :git do
      cmd = "git init && git add . && git commit -m initial"
      sh cmd
    end

    desc "update with latest gem files"
    task :update do
      if `git status` =~ /.*working directory clean.*/
        recursively_remove_files(Dir.pwd)
      else
        puts "working directory not clean, stash or commit your changes"
      end
      $existing_repo = true
      Rake::Task[:'short:heroku:build'].execute
    end

    desc "config a Heroku app the way we need it. Optionally set APPNAME to set heroku app name"
    task :config do
      require 'shortener'
      $name = ENV['APPNAME'] || "shner-#{`whoami`.chomp}"
      cmd = Dir.pwd =~ /heroku$/ ? "" : "cd heroku && "
      cmd += "heroku create #{$name}"
      cmd += " && heroku addons:add redistogo:nano"
      cmd += " && heroku config:add #{Shortener::Configuration.new.to_params}"
      cmd += " && heroku addons:add custom_domains:basic"
      sh cmd
    end

    desc "Push to Heroku"
    task :push do
      cmd = Dir.pwd =~ /heroku$/ ? "" : "cd heroku && "
      cmd += "git push heroku master"
      sh cmd
    end

    desc "Init, configure and push a shortener app to Heroku"
    task :setup => [:git, :config, :push] do
      puts "\nYour app has (hopefully) been created and pushed and available @" +
        " http://#{$name}.heroku.com\n\n" +
        "the Custom Domain Addon has been added, but still needs configuring, for" +
        " steps see\n http://devcenter.heroku.com/articles/custom-domains"
    end # => setup

  end # => heroku

  namespace :data do

    desc "replace hyphenated keys with sanitized ones."
    task :dehyphenate_keys do
      require 'shortener'
      redis = Shortener::Configuration.new.redis
      redis.keys("data:*").each do |k|
        hsh = redis.hgetall(k)
        puts "checking #{hsh}" if ENV['VERBOSE']
        set_count, click_count = hsh['set-count'], hsh['click-count']
        arr = Array.new
        arr.concat([:set_count, set_count]) unless set_count.nil?
        arr.concat([:click_count, click_count]) unless click_count.nil?
        puts "** setting: #{arr.inspect}" if ENV['VERBOSE']
        unless arr.empty? || ENV['DRY_RUN']
          redis.hmset(k, *arr)
          redis.hdel(k, 'set-count')
          redis.hdel(k, 'click-count')
        end
        puts "#{k} afterwards: #{redis.hgetall(k)}" if ENV['VERBOSE']
      end
    end

  end # => data

end # => short
