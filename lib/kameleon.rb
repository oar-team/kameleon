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

# Load the things which must be loaded before anything else
require 'kameleon/utils'
require 'kameleon/error'
require 'kameleon/cli'
require 'kameleon/environment'
require 'kameleon/version'
require 'kameleon/logger'

module Kameleon
  # to force yaml to dump ASCII-8Bit strings as strings
  YAML::ENGINE.yamler='syck'

  # The source root is the path to the root directory of the kameleon gem.
  def self.source_root
    @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
  end


  # add a PROGRESS and NOTICE level
  Log4r::Configurator.custom_levels(:DEBUG, :INFO, :NOTICE,
                                    :PROGRESS, :WARN, :ERROR,
                                    :FATAL)

  class << self
    attr_writer :logger, :env

    def logger
      @logger ||= Log4r::Logger.new("kameleon::[global]")
    end

    def env
      @env ||= Environment.new
    end

  end
end

