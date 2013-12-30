require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

module Kameleon
  class CLI < Thor

    class_option :no_color, :type => :boolean, :default => false,
                 :desc => "Disable colorization in output"
    class_option :debug, :type => :boolean, :default => false,
                 :desc => "Enable debug output"
    class_option :workspace, :aliases => '-w', :type => :string,
                 :desc => 'Change the kameleon current work directory. ' \
                          '(The folder containing your recipes folder).' \
                          ' Default : ./'


    method_option :template, :aliases => "-t",
                  :desc => "Starting from a template",
                  :default => "example_recipe"
    method_option :force,:type => :boolean ,
                  :default => false, :aliases => "-f",
                  :desc => "overwrite the recipe"
    desc "new [RECIPE_NAME]", "Create a new recipe"
    def new(recipe_name)
      # Create a logger right away
      @logger = Log4r::Logger.new("kameleon::cli")
      @logger.info("Cloning template '#{options[:template]}'")
      templates_path = Kameleon.env.templates_path
      recipes_path = Kameleon.env.recipes_path
      template_path = File.join(templates_path, options[:template]) + '.yaml'
      template_recipe = Recipe.new(template_path)

      # TODO add a warning and add a number to the copied file if already
      # exists in the workdir
      Dir::mktmpdir do |tmp_dir|
        FileUtils.cp(template_path, File.join(tmp_dir, recipe_name + '.yaml'))
        template_recipe.sections.each do |key, macrosteps|
          macrosteps.each do |macrostep|
            relative_path = macrostep.path.relative_path_from(templates_path)
            dst = File.join(tmp_dir, File.dirname(relative_path))
            FileUtils.mkdir_p dst
            FileUtils.cp(macrostep.path, dst)
          end
        end
        # Create recipe dir if not exists
        FileUtils.mkdir_p recipes_path
        FileUtils.cp_r(Dir[tmp_dir + '/*'], recipes_path)
      end
      @logger.info("New recipe \"#{recipe_name}\" as been created in #{recipes_path}")
    end

    desc "list", "Lists all defined templates"
    def list
      # TODO: Lists all defined templates
      @logger = Log4r::Logger.new("kameleon::cli")
      @logger.error("Not implemented command")
    end
    map "-L" => :list

    desc "version", "Prints the Kameleon's version information"
    def version
      @logger = Log4r::Logger.new("kameleon::cli")
      @logger.info("Kameleon version #{Kameleon::VERSION}")
    end
    map %w(-v --version) => :version

    desc "build [RECIPE_NAME]", "Build box from the recipe"
    method_option :force, :type => :boolean ,
                  :default => false, :aliases => "-f",
                  :desc => "force the build"
    def build(recipe_name)
      @logger = Log4r::Logger.new("kameleon::cli")
      @logger.info("Starting build recipe '#{recipe_name}'")
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      Kameleon::Engine.new(Recipe.new(recipe_path)).build
    end

    # Hack Thor to init Kameleon env soon
    def self.init(base_config)
      options = base_config[:shell].base.options
      # Update env
      Kameleon.env = Kameleon::Environment.new(options)
      # configure logger
      ENV["KAMELEON_LOG"] = "debug" if options.debug
      if ENV["KAMELEON_LOG"] && ENV["KAMELEON_LOG"] != ""
        level_name = ENV["KAMELEON_LOG"]
      else
        level_name = "info"
      end
      # Require Log4r and define the levels we'll be using
      require 'log4r-color/config'
      Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)

      begin
        level = Log4r.const_get(level_name.upcase)
      rescue NameError
        fail KameleonError, "Invalid KAMELEON_LOG level is set: #{level_name}.\n" \
                            "Please use one of the standard log levels: debug," \
                            " info, warn, or error"
      end
      if !$stdout.tty? or options.no_color
        console_output = Log4r::Outputter.stdout
      else
        console_output = Log4r::ColorOutputter.new 'console', {:colors =>
          {
            :debug  => :white,
            :info   => :green,
            :warn   => :yellow,
            :error  => :red,
            :fatal  => {:color => :red, :background => :white}
          }
        }
      end

      logger = Log4r::Logger.new('kameleon')
      logger.outputters << console_output
      logger.outputters << Log4r::FileOutputter.new('logfile',
                                                    :trunc=>false,
                                                    :filename => 'kameleon.log')
      logger.level = level
      logger = nil
      # Create a logger right away
      logger = Log4r::Logger.new("kameleon::cli")
      logger.debug("`kameleon` invoked: #{ARGV.inspect}")
    end

    def self.start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config) { init(config) }
    end
  end
end
