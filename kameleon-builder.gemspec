# coding: utf-8

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kameleon/version'

Gem::Specification.new do |s|
  s.name          = 'kameleon-builder'
  s.version       = Kameleon::VERSION
  s.date          = Time.now.strftime('%Y-%m-%d')
  s.authors       = ['Salem Harrache',
                     'Michael Mercier',
                     'Cristan Ruiz',
                     'Pierre Neyron',
                     'Bruno Bzeznik']
  s.email         = ['salem@harrache.info',
                     'michael.mercier@libr.fr',
                     'camilo1729@gmail.com',
                     'pierre.neyron@imag.fr',
                     'bruno.bzeznik@imag.fr']
  s.symmary       = 'The mindful appliance builder'
  s.description   = 'Kameleon is a tool to build system appliances, possibly from scratch'
  s.homepage      = 'http://kameleon.imag.fr/'
  s.license       = 'GPL-2.0-or-later'

  s.files         = `git ls-files`.split($/)
  s.files.reject! { |file| file.start_with?('docs/') }
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(tests|s|features)/})
  s.require_paths = ['lib']

  s.add_dependency 'childprocess', '~> 0.5.3', '>= 0.3.0'
  s.add_dependency 'thor', '~> 1'
  s.add_dependency 'table_print', '~> 1.5'
  s.add_dependency 'psych', '~> 2.0'
  s.add_dependency 'ruby-graphviz', '~> 1.2'
  s.add_dependency 'progressbar', '~> 1'

  s.requirements = ['polipo 1.0.3, or greater', 'graphviz 2.38.0 or greater']
end
