require "kameleon/version"
require 'yaml'
require 'fileutils'
require 'optparse'
require 'erb'
require 'session'
require 'tempfile'
require 'pp'

module Kameleon
  autoload :UI,        'kameleon/ui'
end
