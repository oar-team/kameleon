module Kameleon

  # This class allows access to the recipes, CLI, etc. all in the scope of
  # this environment
  class Environment

    attr_accessor :workspace
    attr_accessor :templates_path
    attr_accessor :recipes_path
    attr_accessor :build_path
    attr_accessor :log_file

    # Hash element of all recipes available
    attr_accessor :recipes

    # Hash element of all templates available
    attr_accessor :templates

    def initialize(options = {})
      @logger = Log4r::Logger.new("kameleon::environment")
      # symbolify commandline options
      options = options.inject({}) {|result,(key,value)| result.update({key.to_sym => value})}
      workspace = options[:workspace]
      defaults = {
        :workspace => Pathname.new(File.join(Kameleon.source_root, 'templates')),
        :templates_path => Pathname.new(File.join(Kameleon.source_root, 'templates')),
        :recipes_path => Pathname.new(File.join(workspace, "recipes")),
        :build_path => Pathname.new(File.join(workspace, "builds")),
        :log_file => Pathname.new(File.join(workspace, "kameleon.log"))
      }

      options = defaults.merge(options)
      @logger.debug("Environment initialized (#{self})")
      # Injecting all variables of the options and assign the variables
      options.each do |key, value|
        instance_variable_set("@#{key}".to_sym, options[key])
        @logger.debug(" - #{key} : #{options[key]}")
      end

      # Definitions
      @recipes = nil
      @templates = nil

      return self
    end
  end
end
