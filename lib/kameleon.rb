require 'yaml'
require 'fileutils'
require 'optparse'
require 'erb'
require 'session'
require 'tempfile'
require 'pp'

module Kameleon
end


# Load the things which must be loaded before anything else
require 'kameleon/error'
require 'kameleon/cli'
require 'kameleon/ui'
require 'kameleon/environment'
require 'kameleon/version'
