# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "shortener/version"

Gem::Specification.new do |s|
  s.name        = "short"
  s.version     = Shortener::VERSION
  s.authors     = ["Jake Wilkins"]
  s.email       = ["jake@jakewilkins.com"]
  s.homepage    = ""
  s.summary     = %q{A Link Shortener}
  s.description = %q{A (hopefully) easy and handy deployable APIable way to shorten links.}

  #s.rubyforge_project = "shortener"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
   s.add_development_dependency "sinatra"
   s.add_development_dependency "redis-namespace"
   s.add_development_dependency "haml"
   s.add_development_dependency "turn"
   #s.add_runtime_dependency "rest-client"
end
