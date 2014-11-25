module Kameleon

  # This class allows access to the recipes, CLI, etc. all in the scope of
  # this environment
  class Environment

    def script?
      @script
    end

    def initialize(options = {})
      # symbolify commandline options
      options = options.inject({}) {|result,(key, value)| result.update({key.to_sym => value})}
      workspace = File.expand_path(Dir.pwd)
      # templates_path = File.expand_path(options[:templates_path] || Kameleon.default_templates_path)
      build_path = File.expand_path(options[:build_path] || File.join(workspace, "build"))
      cache_path = File.expand_path(options[:cache_path] || File.join(build_path, "cache"))
      repositories_path = File.expand_path(Kameleon.default_values[:repositories_path])
      env_options = {
        :workspace => Pathname.new(workspace),
        # :templates_path => Pathname.new(templates_path),
        :build_path => Pathname.new(build_path),
        :cache_path => Pathname.new(cache_path),
        :repositories_path => Pathname.new(repositories_path),
        :root_dir => Pathname.new(workspace),
      }
      options = Kameleon.default_values.merge(options).merge(env_options)
      Kameleon.ui.debug("Environment initialized (#{self})")
      # Injecting all variables of the options and assign the variables
      options.each do |key, value|
        self.class.__send__(:attr_accessor, "#{key}")
        instance_variable_set("@#{key}".to_sym, options[key])
        Kameleon.ui.debug("  @#{key} : #{options[key]}")
      end
      @debug = true if ENV['KAMELEON_DEBUG']

      Dir.mkdir(@repositories_path.to_path) unless File.exists?(@repositories_path.to_path)

    end
  end
end
