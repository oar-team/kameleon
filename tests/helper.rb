require 'minitest/unit'
require 'minitest/autorun'
require 'minitest/pride'
require 'kameleon'


if ENV['COVERAGE']
  require 'simplecov'
  require 'coveralls'

  SimpleCov.start { add_filter '/tests/' }
  SimpleCov.merge_timeout 300
  SimpleCov.command_name 'unit'
end
