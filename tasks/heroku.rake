$gem_dir = File.expand_path(File.dirname(File.dirname(__FILE__)))
def gem_file(*args)
  ret = args.map {|f| File.join($gem_dir, f)}.join(" ")
end
namespace :heroku do

  desc "Build a Heroku Ready Git repo"
  task :build do
    cmd = "mkdir heroku"
    cmd += " && mkdir heroku/server"
    cmd += " && cp -r #{gem_file("lib/shortener/server/*")} ./heroku/server/"
    cmd += " && cp #{gem_file('lib/shortener/server.rb')} ./heroku/main.rb"
    cmd += " && cp #{gem_file('lib/shortener/configuration.rb')} ./heroku/configuration.rb"
    cmd += " && mv ./heroku/server/config.ru.template ./heroku/config.ru"
    cmd += " && mv ./heroku/server/Gemfile ./heroku/server/Gemfile.lock ./heroku"
    cmd += " && git init heroku && cd heroku && git add . && git commit -m initial"
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
