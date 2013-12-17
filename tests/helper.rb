if ENV['COVERAGE']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.profiles.define 'kameleon' do
    add_filter './tests/'
    add_filter './spec/'
    add_filter './autotest/'

    add_group 'Binaries', 'bin/'
    add_group 'Libraries', 'lib/'
  end

  SimpleCov.start 'kameleon'
  SimpleCov.merge_timeout 300
  SimpleCov.command_name 'unit'
end

require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'kameleon'
