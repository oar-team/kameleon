require 'fileutils'
require 'optparse'
require 'erb'
require 'ostruct'
require 'tempfile'
require 'pp'
require 'thor'
require 'childprocess'
require 'pathname'
require 'table_print'
require 'yaml'

module Kameleon
  class << self
    attr_writer :env
    attr_writer :ui
    attr_writer :source_root
    attr_writer :log_on_progress

    # The source root is the path to the root directory of the kameleon gem.
    def source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end

    def default_templates_path
      File.join(Kameleon.source_root, 'templates')
    end

    def env
      @env ||= Environment.new
    end

    def ui
      @ui ||= UI::Shell.new
    end

    def log_on_progress
      @log_on_progress ||= false
    end
  end
end

# Load the things which must be loaded before anything else
require 'kameleon/compat'
require 'kameleon/utils'
require 'kameleon/error'
require 'kameleon/cli'
require 'kameleon/environment'
require 'kameleon/version'
require 'kameleon/ui'
