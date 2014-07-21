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
    attr_writer :templates_path
    attr_writer :templates_names
    attr_writer :templates_files
    attr_writer :log_on_progress

    # The source root is the path to the root directory of the kameleon gem.
    def source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end

    def templates_path
      @templates_path ||= Pathname.new(File.join(source_root, 'templates'))
    end

    def templates_files
      if @templates.nil?
        files = Dir.foreach(templates_path).map do |f|
          Pathname.new(File.join(templates_path, f)) if f.include?(".yaml")
        end
        @templates = files.compact
      end
      @templates
    end

    def templates_names
      if @templates_names.nil?
        names = templates_files.map do |f|
          f.basename(f.extname).to_s
        end
        @templates_names = names
      end
      @templates_names
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
