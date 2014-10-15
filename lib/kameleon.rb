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

require 'kameleon/ui'

module Kameleon
  class << self
    attr_writer :env
    attr_writer :ui
    attr_writer :source_root
    attr_writer :log_on_progress
    attr_writer :userdir
    attr_writer :userconf_path
    attr_writer :repositories_path
    attr_writer :default_values

    # The source root is the path to the root directory of the kameleon gem.
    def source_root
      @source_root ||= Pathname.new(File.expand_path('../../', __FILE__))
    end

    def erb_dirpath
      File.join(Kameleon.source_root, 'erb')
    end

    def userdir
      @userdir ||= Pathname.new(File.join('~', '.kameleon.d'))
      Dir.mkdir(File.expand_path(@userdir.to_path)) unless File.exists?(File.expand_path(@userdir.to_path))
      @userdir
    end

    def userconf_path
      @userconf_path ||= Pathname.new(File.join(File.expand_path(userdir.to_path), 'config'))
    end

    def init_userconf()
      if not File.exists?(Kameleon.userconf_path) or File.zero?(Kameleon.userconf_path)
        File.open(Kameleon.userconf_path, 'w+') do |file|
          userconf_erb = File.join(Kameleon.erb_dirpath, "userconf.erb")
          erb = ERB.new(File.open(userconf_erb, 'rb') { |f| f.read })
          result = erb.result(binding)
          file.write(result)
        end
      end
    end

    def load_userconf
      if File.exists?(Kameleon.userconf_path) and not File.zero?(Kameleon.userconf_path)
        yaml_conf = YAML.load_file Kameleon.userconf_path
        unless yaml_conf.kind_of? Hash
          yaml_conf = {}
        end
      else
        yaml_conf = {}
      end
      return yaml_conf
    end

    def default_values
      userconf = load_userconf
      @default_values ||= {
        :color => userconf.fetch("color", true),
        :debug => userconf.fetch("debug", false),
        :script => userconf.fetch("script", false),
        :repositories_path =>  userconf.fetch("repositories_path",
                                          File.join(userdir.to_path, 'repos')),
      }
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
require 'kameleon/repository'
require 'kameleon/cli'
require 'kameleon/environment'
require 'kameleon/version'
