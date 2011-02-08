# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "bitemporal/version"

Gem::Specification.new do |s|
  s.name        = "bitemporal"
  s.version     = Bitemporal::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Joseph HALTER", "Jonathan TRON"]
  s.email       = ["team@openhood.com"]
  s.homepage    = "http://github.com/openhood/bitemporal"
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "bitemporality"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end