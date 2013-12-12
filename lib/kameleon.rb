require 'yaml'
require 'fileutils'
require 'optparse'
require 'erb'
require 'session'
require 'tempfile'
require 'pp'
require 'thor'

# Load the things which must be loaded before anything else
require 'kameleon/error'
require 'kameleon/utils'
require 'kameleon/cli'
require 'kameleon/ui'
require 'kameleon/environment'
require 'kameleon/version'


module Kameleon
  # The source root is the path to the root directory of the kameleon gem.
  def self.source_root
    @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
  end
end

