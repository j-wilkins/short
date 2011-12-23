# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "shortener/version"

Gem::Specification.new do |s|
  s.name        = "shortener"
  s.version     = Shortener::VERSION
  s.authors     = ["jake"]
  s.email       = ["jake.wilkins@adfitech.com"]
  s.homepage    = ""
  s.summary     = %q{Link Shortener}
  s.description = %q{A (hopefully) easy and handy way to shorten links.}

  s.rubyforge_project = "shortener"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
   s.add_development_dependency "turn"
   #s.add_runtime_dependency "rest-client"
end
