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
    no_commands do
      def logger
        @logger ||= Log4r::Logger.new("kameleon::[cli]")
      end
    end

    method_option :template, :aliases => "-t", :desc => "Starting from a template",
                  :default => "example_recipe"
    method_option :force,:type => :boolean , :default => false, :aliases => "-f",
                  :desc => "overwrite the recipe"
    desc "new [RECIPE_NAME]", "Create a new recipe"
    def new(recipe_name)
      logger.notice("Cloning template '#{options[:template]}'")
      templates_path = Kameleon.env.templates_path
      recipes_path = Kameleon.env.recipes_path

      template_path = File.join(templates_path, options[:template]) + '.yaml'
      template_recipe = RecipeTemplate.new(template_path)
      template_recipe.copy_template(recipes_path,
                                    recipe_name,
                                    options[:force])
      logger.notice("New recipe \"#{recipe_name}\" "\
                    "as been created in #{recipes_path}")
    end

    desc "list", "Lists all defined templates"
    def list
      # TODO: Lists all defined templates
      logger.warn("Not implemented command")
    end
    map "-L" => :list

    desc "version", "Prints the Kameleon's version information"
    def version
      puts "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version


    desc "build [RECIPE_NAME]", "Build box from the recipe"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "change the build directory path"
    method_option :from_checkpoint, :type => :string ,
                  :default => nil,
                  :desc => "Using specific checkpoint to build the image. " \
                           "Default value is the last checkpoint."
    method_option :no_checkpoint, :type => :boolean ,
                  :default => false,
                  :desc => "Do not use previous checkpoint"
    def build(recipe_name)
      logger.notice("Starting build recipe '#{recipe_name}'")
      start_time = Time.now.to_i
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.build
      total_time = Time.now.to_i - start_time
      logger.notice("")
      logger.notice("Build recipe '#{recipe_name}' is completed !")
      logger.notice("Build total duration : #{total_time} secs")
      logger.notice("Build directory : #{engine.cwd}")
      logger.notice("Kameleon build recipe file : #{engine.build_recipe_path}")
      logger.notice("Kameleon log file : #{Kameleon.env.log_file}")

    desc "checkpoints [RECIPE_NAME]", "List all availables checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def checkpoints(recipe_name)
      Log4r::Outputter['console'].level = Log4r::ERROR unless options.debug
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.pretty_checkpoints_list
    end

    # Hack Thor to init Kameleon env soon
    def self.init(base_config)
      options = base_config[:shell].base.options
      workspace ||= options[:workspace] || ENV['KAMELEON_WORKSPACE'] || Dir.pwd
      FileUtils.mkdir_p workspace
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
      format = ConsoleFormatter.new
      # format = Log4r::PatternFormatter.new(:pattern => '%11c: %M')
      if !$stdout.tty? or options.no_color
        console_output = Log4r::StdoutOutputter.new('console',
                                                    :formatter => format)
      else
        console_output = Log4r::ColorOutputter.new 'console', {
          :colors => { :debug  => :light_black,
                       :info   => :green,
                       :notice => :light_blue,
                       :progress => :light_blue,
                       :warn   => :yellow,
                       :error  => :red,
                       :fatal  => :red,
                     },
          :formatter => format,
        }
      end
      logger = Log4r::Logger.new('kameleon')
      logger.outputters << console_output
      log_file = File.join(workspace, "kameleon.log")
      format_file = FileFormatter.new
      logger.outputters << Log4r::FileOutputter.new('logfile',
                                                    :trunc=>false,
                                                    :filename => log_file,
                                                    :formatter => format_file)
      logger.level = level
      logger = nil
      Kameleon.logger.debug("`kameleon` invoked: #{ARGV.inspect}")
      # Update env
      env_options = options.merge({:workspace => workspace})
      Kameleon.env = Kameleon::Environment.new(env_options)
    end

    def self.start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config) { init(config) }
    end
  end
end
