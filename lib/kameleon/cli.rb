require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

module Kameleon
  class CLI < Thor


    class_option :color, :type => :boolean, :default => true,
                 :desc => "Enable colorization in output"
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

    method_option :template, :aliases => "-t",
                  :desc => "Starting from a template", :required => true,
                  :enum => Kameleon.templates_names
    method_option :force,:type => :boolean,
                  :default => false, :aliases => "-f",
                  :desc => "overwrite the recipe"
    desc "new [RECIPE_NAME]", "Creates a new recipe"
    def new(recipe_name)
      logger.notice("Cloning template '#{options[:template]}'")
      templates_path = Kameleon.env.templates_path
      recipes_path = Kameleon.env.recipes_path

      template_path = File.join(templates_path, options[:template]) + '.yaml'
      template_recipe = RecipeTemplate.new(template_path)
      template_recipe.copy_template(recipes_path,
                                    recipe_name,
                                    options[:force])
      recipe_path = File.join(recipes_path, recipe_name + ".yaml")
      logger.notice("New recipe \"#{recipe_name}\" "\
                    "as been created in #{recipe_path}")
    end

    desc "templates", "Lists all defined templates"
    def templates
      Log4r::Outputter['console'].level = Log4r::ERROR unless Kameleon.env.debug
      puts "The following templates are available in " \
                 "#{ Kameleon.templates_path }:"
      templates_hash = []
      Kameleon.templates_files.each do |f|
        begin
        recipe = RecipeTemplate.new(f)
        templates_hash.push({
          "name" => recipe.name,
          "description" => recipe.metainfo['description'],
        })
        rescue => e
          raise e if Kameleon.env.debug
        end
      end
      tp templates_hash, {"name" => {:width => 30}}, { "description" => {:width => 60}}
    end

    desc "version", "Prints the Kameleon's version information"
    def version
      Log4r::Outputter['console'].level = Log4r::OFF unless Kameleon.env.debug
      puts "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version


    desc "build [RECIPE_NAME]", "Builds the appliance from the recipe"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    method_option :from_checkpoint, :type => :string ,
                  :default => nil,
                  :desc => "Using specific checkpoint to build the image. " \
                           "Default value is the last checkpoint."
    method_option :no_checkpoint, :type => :boolean ,
                  :default => false,
                  :desc => "Do not use checkpoints"
    method_option :cache, :type => :boolean,
                  :default => false,
                  :desc => "generate a persistent cache for the appliance."
    method_option :from_cache, :type => :string ,
                  :default => nil,
                  :desc => "Using a persistent cache tar file to build the image."
    method_option :proxy_path, :type => :string ,
                  :default => nil,
                  :desc => "Full path of the proxy binary to use for the persistent cache."

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
      logger.notice("Build recipe file : #{engine.build_recipe_path}")
      logger.notice("Log file : #{Kameleon.env.log_file}")
    end

    desc "checkpoints [RECIPE_NAME]", "Lists all availables checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def checkpoints(recipe_name)
      Log4r::Outputter['console'].level = Log4r::ERROR unless Kameleon.env.debug
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.pretty_checkpoints_list
    end

    desc "clear [RECIPE_NAME]", "Cleaning out context and removing all checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def clear(recipe_name)
      Log4r::Outputter['console'].level = Log4r::INFO
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.clear
    end

    desc "completions command", "Used for shell completion", :hide => true
    def completions(*args)
      if %w(clear checkpoints build).include?(args[0])
          recipes = Dir.foreach(Kameleon.env.recipes_path).map do |f|
            File.basename(f, ".yaml") if f.include?(".yaml")
          end
          puts recipes.compact
      end
    end

    desc "commands", "Lists all available commands", :hide => true
    def commands
      puts CLI.all_commands.keys - ["commands", "completions"]
    end

    # Hack Thor to init Kameleon env soon
    def self.init(base_config)
      options = base_config[:shell].base.options
      workspace ||= options[:workspace] || ENV['KAMELEON_WORKSPACE'] || Dir.pwd
      env_options = options.merge({:workspace => workspace})
      FileUtils.mkdir_p workspace
      # configure logger
      env_options["debug"] = true if ENV["KAMELEON_LOG"] == "debug"
      ENV["KAMELEON_LOG"] = "debug" if env_options["debug"]
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
      if !$stdout.tty? or !env_options["color"]
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
      logger.level = level
      logger = nil
      Kameleon.logger.debug("`kameleon` invoked: #{ARGV.inspect}")
      Kameleon.env = Kameleon::Environment.new(env_options)
    end

    def self.start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config) { init(config) }
    end
  end
end
