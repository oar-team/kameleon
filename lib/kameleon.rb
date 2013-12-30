require 'securerandom'
require 'yaml'
require 'fileutils'
require 'optparse'
require 'erb'
require 'tempfile'
require 'pp'
require 'thor'
require 'childprocess'

# Load the things which must be loaded before anything else
require 'kameleon/utils'
require 'kameleon/error'
require 'kameleon/cli'
require 'kameleon/ui'
require 'kameleon/environment'
require 'kameleon/version'


module Kameleon
  # The source root is the path to the root directory of the kameleon gem.
  def self.source_root
    @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
  end

  class << self
    attr_writer :ui, :env

    def ui
      @ui ||= Kameleon::UI::Shell.new
    end

    def env
      @env ||= Environment.new
    end

  end
end

