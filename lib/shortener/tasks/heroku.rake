$gem_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
def gem_file(f)
  #ret = args.map {|f| File.join($gem_dir, f)}.join(" ")
  File.join($gem_dir, f.to_s)
end

def _file(f)
  File.join(Dir.pwd, f.to_s)
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

def _l(action, start, nd)
  puts "#{action}: #{start} => #{nd}" if ENV['VERBOSE']
end

namespace :heroku do

  desc "Build a Heroku Ready Git repo"
  task :build do
    [:heroku, :'heroku/server', :'heroku/server/public', :'heroku/server/views', 
     :'heroku/server/views/s3', :'heroku/server/public/flash', 
     :'heroku/server/public/skin', :'heroku/server/public/images', 
     :'heroku/server/public/skin/blue.monday'].each do |f|
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
        end_point = _file(:"heroku/#{_ep(f)}")
        _l(:copying, f, end_point)
        FileUtils.cp(f, end_point)
      end
    end
    _s, _e = gem_file('server.rb'), _file(:'heroku/main.rb')
    _l(:copying, _s, _e)
    FileUtils.cp(_s, _e)
    _s, _e = gem_file('configuration.rb'), _file(:'heroku/configuration.rb')
    _l(:copying, _s, _e)
    FileUtils.cp(_s, _e)
    _s, _e = _file('heroku/server/config.ru.template'), _file(:'heroku/config.ru')
    _l(:renaming, _s, _e)
    FileUtils.mv(_s, _e)
    _s, _e = _file('heroku/server/Gemfile'), _file(:'heroku/Gemfile')
    _l(:renaming, _s, _e)
    FileUtils.mv(_s, _e)
    _s, _e = _file(:'heroku/server/Gemfile.lock'), _file(:'heroku/Gemfile.lock')
    _l(:renaming, _s, _e)
    FileUtils.mv(_s, _e)
  end

  desc "initialize the Git repo"
  task :git do
    cmd = "git init heroku && cd heroku && git add . && git commit -m initial"
    sh cmd
  end

  desc "config a Heroku app the way we need it. Optionally set APPNAME to set heroku app name"
  task :config do
    require_relative '../lib/shortener'
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

  desc "Build, configure and push a shortener app to Heroku"
  task :setup => [:build, :config, :push] do
    puts "\nYour app has (hopefully) been created and pushed and available @" +
      " http://#{$name}.heroku.com\n\n" +
      "the Custom Domain Addon has been added, but still needs configuring, for" +
      " steps see\n http://devcenter.heroku.com/articles/custom-domains"
  end

end
