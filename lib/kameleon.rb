require 'securerandom'
require 'yaml'
require 'fileutils'
require 'optparse'
require 'erb'
require 'ostruct'
require 'tempfile'
require 'pp'
require 'thor'
require 'childprocess'
require 'log4r-color'
require 'log4r-color/configurator'
require 'pathname'
require 'table_print'

module Kameleon
  # to force yaml to dump ASCII-8Bit strings as strings
  YAML::ENGINE.yamler='psych'

  # add a PROGRESS and NOTICE level
  Log4r::Configurator.custom_levels(:DEBUG, :INFO, :NOTICE,
                                    :PROGRESS, :WARN, :ERROR,
                                    :FATAL)

  class << self
    attr_writer :logger, :env, :source_root, :templates_path, :templates_names,
                :templates_files

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

    def logger
      @logger ||= Log4r::Logger.new("kameleon::[global]")
    end

    def env
      @env ||= Environment.new
    end

  end
end

# Load the things which must be loaded before anything else
require 'kameleon/utils'
require 'kameleon/error'
require 'kameleon/cli'
require 'kameleon/environment'
require 'kameleon/version'
require 'kameleon/logger'
