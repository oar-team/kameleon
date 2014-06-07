require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

module Kameleon
  class CLI < Thor


    class_option :color, :type => :boolean, :default => true,
                 :desc => "Enable colorization in output"
    class_option :debug, :type => :boolean, :default => false,
                 :desc => "Enable debug output"
    map %w(-h --help) => :help

    no_commands do
      def logger
        @logger ||= Log4r::Logger.new("kameleon::[kameleon]")
      end
    end

    method_option :force,:type => :boolean,
                  :default => false, :aliases => "-f",
                  :desc => "overwrite all existing files"
    desc "import [TEMPLATE_NAME]", "Imports the given template"
    def import(template_name)
      templates_path = Kameleon.env.templates_path
      template_path = File.join(templates_path, template_name) + '.yaml'
      begin
        template_recipe = RecipeTemplate.new(template_path)
        logger.notice("Importing template '#{template_name}'...")
        template_recipe.copy_template(options[:force])
      rescue
        raise TemplateNotFound, "Template '#{template_name}' not found. " \
                                "To see all templates, run the command "\
                                "`kameleon templates`"
      else
        logger.notice("done")
      end
    end

    method_option :force,:type => :boolean,
                  :default => false, :aliases => "-f",
                  :desc => "overwrite the recipe"
    desc "new [RECIPE_NAME] [TEMPLATE_NAME]", "Creates a new recipe"
    def new(recipe_name, template_name)
      if recipe_name == template_name
        fail RecipeError, "Recipe name should be different from template name"
      end
      templates_path = Kameleon.env.templates_path
      template_path = File.join(templates_path, template_name) + '.yaml'
      begin
        template_recipe = RecipeTemplate.new(template_path)
        logger.notice("Cloning template '#{template_name}'...")
        template_recipe.copy_template(options[:force])
        template_recipe.copy_extended_recipe(recipe_name, options[:force])
      rescue
        raise TemplateNotFound, "Template '#{template_name}' not found\n" \
                                "To see all templates, run the command "\
                                "`kameleon templates`"
      else
        logger.notice("done")
      end
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
      templates_hash = templates_hash.sort_by{ |k| k["name"] }
      tp templates_hash, {"name" => {:width => 30}}, { "description" => {:width => 60}}
    end

    desc "version", "Prints the Kameleon's version information"
    def version
      Log4r::Outputter['console'].level = Log4r::OFF unless Kameleon.env.debug
      puts "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version

    desc "build [RECIPE_PATH]", "Builds the appliance from the recipe"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    method_option :clean, :type => :boolean ,
                  :default => false,
                  :desc => "Run the command `kameleon clean` first"
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

    def build(recipe_path)
      clean(recipe_path) if options[:clean]
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      logger.notice("Starting build recipe '#{recipe_path}'")
      start_time = Time.now.to_i
      engine.build
      total_time = Time.now.to_i - start_time
      logger.notice("")
      logger.notice("Build recipe '#{recipe_path}' is completed !")
      logger.notice("Build total duration : #{total_time} secs")
      logger.notice("Build directory : #{engine.cwd}")
      logger.notice("Build recipe file : #{engine.build_recipe_path}")
      logger.notice("Log file : #{Kameleon.env.log_file}")
    end

    desc "checkpoints [RECIPE_PATH]", "Lists all availables checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def checkpoints(recipe_path)
      Log4r::Outputter['console'].level = Log4r::ERROR unless Kameleon.env.debug
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.pretty_checkpoints_list
    end

    desc "clear [RECIPE_PATH]", "Cleaning out context and removing all checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def clear(recipe_path)
      Log4r::Outputter['console'].level = Log4r::INFO
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.clear
    end

    desc "commands", "Lists all available commands", :hide => true
    def commands
      puts CLI.all_commands.keys - ["commands", "completions"]
    end

    # Hack Thor to init Kameleon env soon
    def self.init(base_config)
      env_options = Hash.new
      env_options.merge! base_config[:shell].base.options.clone
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
        level = Log4r.const_get("INFO")
        $stderr << "Invalid KAMELEON_LOG level is set: #{level_name}.\n" \
                   "Please use one of the standard log levels: debug," \
                   " info, warn, or error\n"
        raise KameleonError
      end
      format = ConsoleFormatter.new
      # format = Log4r::PatternFormatter.new(:pattern => '%11c: %M')
      if !$stdout.tty? or !env_options["color"]
        console_output = Log4r::StdoutOutputter.new('console',
                                                    :formatter => format)
        Diffy::Diff.default_format = :text
      else
        console_output = Log4r::ColorOutputter.new 'console', {
          :colors => { :debug  => :light_black,
                       :info   => :green,
                       :progress_info => :green,
                       :notice => :light_blue,
                       :progress_notice => :light_blue,
                       :warn   => :yellow,
                       :error  => :red,
                       :progress_error => :red,
                       :fatal  => :red,
                     },
          :formatter => format,
        }
        Diffy::Diff.default_format = :color
      end
      logger = Log4r::Logger.new('kameleon')
      logger.outputters << console_output
      format_file = FileFormatter.new
      logger.level = level
      Kameleon.logger.debug("`kameleon` invoked: #{ARGV.inspect}")
      Kameleon.env = Kameleon::Environment.new(env_options)
      filelog = Log4r::FileOutputter.new('logfile',
                                         :trunc=>false,
                                         :filename => Kameleon.env.log_file.to_s,
                                         :formatter => format_file)
      logger.outputters << filelog
      logger = nil
    end

    def self.start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config) { init(config) }
    end
  end
end
