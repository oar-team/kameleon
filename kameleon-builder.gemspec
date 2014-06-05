# coding: utf-8
RUBYONEX = RUBY_VERSION < "2.0"

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
  s.description   = %q{The mindful appliance builder}
  s.summary       = %q{Kameleon is a tool to build virtual machines from scratch}
  s.homepage      = "http://kameleon.readthedocs.org/"
  s.license       = "GPL-2"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(tests|s|features)/})
  s.require_paths = ["lib"]

  s.required_ruby_version     = RUBYONEX ? '>= 1.9.3' : '>= 2.0.0'

  s.add_dependency 'childprocess', '~> 0.5'
  s.add_dependency 'thor', '~> 0.15'
  s.add_dependency 'table_print', '~> 1.5'
  s.add_dependency 'log4r-color', '~> 1.2'
  s.add_dependency 'syck', '~> 1.0.0' unless RUBYONEX
  s.add_dependency 'diffy', '~> 3.0.4'

  s.add_development_dependency 'pry', '~> 0.9'
  s.add_development_dependency 'pry-debugger', '~> 0.2'
  s.add_development_dependency 'rake', '~> 10.1'
  s.add_development_dependency 'minitest', '~> 4.7'
  s.add_development_dependency 'coveralls', '~> 0.7'
end
