module Kameleon

  # This class allows access to the recipes, CLI, etc. all in the scope of
  # this environment
  class Environment

    attr_accessor :workspace
    attr_accessor :templates_path
    attr_accessor :build_path
    attr_accessor :log_file
    attr_accessor :debug


    def initialize(options = {})
      @logger = Log4r::Logger.new("kameleon::[kameleon]")
      # symbolify commandline options
      options = options.inject({}) {|result,(key,value)| result.update({key.to_sym => value})}
      workspace = File.expand_path(Dir.pwd)
      build_path = File.expand_path(options[:build_path] || File.join(workspace, "build"))
      defaults = {
        :workspace => Pathname.new(workspace),
        :templates_path => Kameleon.templates_path,
        :templates_names => Kameleon.templates_names,
        :build_path => Pathname.new(build_path),
        :log_file => Pathname.new(File.join(workspace, "kameleon.log"))
      }
      options = defaults.merge(options)
      @logger.debug("Environment initialized (#{self})")
      # Injecting all variables of the options and assign the variables
      options.each do |key, value|
        instance_variable_set("@#{key}".to_sym, options[key])
        @logger.debug("  @#{key} : #{options[key]}")
      end
    end
  end
end
