module Kameleon

  # This class allows access to the recipes, CLI, etc. all in the scope of
  # this environment
  class Environment

    attr_accessor :workspace
    attr_accessor :templates_dir
    attr_accessor :recipes_dir
    attr_accessor :build_dir

    attr_writer :ui

    # Hash element of all recipes available
    attr_accessor :recipes

    # Hash element of all templates available
    attr_accessor :templates

    def initialize(options = {})
      # symbolify commandline options
      options = options.inject({}) {|result,(key,value)| result.update({key.to_sym => value})}
      workspace = options[:workspace] || ENV['KAMELEON_WORKSPACE'] || Dir.pwd
      defaults = {
        :workspace => workspace,
        :templates_dir => File.expand_path(File.join(File.dirname(__FILE__), "..", "..", 'templates')),
        :recipes_dir => File.join(workspace, "recipes"),
        :build_dir => File.join(workspace, "builds"),
      }

      options = defaults.merge(options)
      Kameleon.ui.debug "Environment initialized (#{self})"
      # Injecting all variables of the options and assign the variables
      options.each do |key, value|
        instance_variable_set("@#{key}".to_sym, options[key])
        Kameleon.ui.debug  " - #{key} : #{options[key]}"
      end

      # Definitions
      @recipes = nil
      @templates = nil

      return self
    end

    def ui
      @ui ||= UI.new(self)
    end

    def cli(*args)
      CLI.start(args.flatten, :env => self)
    end

  end
end
