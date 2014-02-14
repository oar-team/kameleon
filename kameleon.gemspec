# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kameleon/version'

Gem::Specification.new do |s|
  s.name          = "kameleon-builder"
  s.version       = Kameleon::VERSION
  s.authors       = ["Salem Harrache",
                     "Michael Mercier",
                     "Cristan Ruiz",
                     "Bruno Bzeznik"]
  s.email         = ["salem.harrache@inria.fr",
                     "michael.mercier@inria.fr",
                     "cristian.ruiz@imag.fr",
                     "bruno.bzeznik@imag.fr"]
  s.description   = %q{Kameleon is a tool to build virtual machines from scratch}
  s.summary       = s.description
  s.homepage      = ""
  s.license       = "GPL-2"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(tests|s|features)/})
  s.require_paths = ["lib"]

  s.add_runtime_dependency "childprocess", "~> 0.3.7"
  s.add_runtime_dependency "session", "~> 3.1.0"
  s.add_runtime_dependency "thor", "~> 0.15"
  s.add_runtime_dependency "table_print"
  s.add_runtime_dependency "log4r-color", "~> 1.2.2"

  s.add_development_dependency "pry"
  s.add_development_dependency "pry-debugger"
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest", "~> 4.7.3"
  s.add_development_dependency "coveralls"
end
