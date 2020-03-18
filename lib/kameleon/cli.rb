require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'
require 'tempfile'
require 'graphviz'

module Kameleon

  module CLI

    class Repository < Thor
      include Thor::Actions

      desc "add [NAME] [URL]", "Adds a new named <name> repository at <url>."
      method_option :branch, :type => :string ,
                    :default => nil,
                    :desc => "checkout <branch>",
                    :aliases => "-b"
      def add(name, url)
        Kameleon::Repository.add(name, url, options)
      end

      desc "list", "Lists available repositories."
      def list
        Kameleon::Repository.list
      end

      desc "update [NAME]", "Updates a named <name> repository"
      def update(name)
        Kameleon::Repository.update(name)
      end
      map %w(-h --help) => :help
      map %w(ls) => :list
    end


    class Template < Thor
      include Thor::Actions

#      register CLI::Repository, 'repository', 'repository', 'Manages set of remote git repositories'

      def self.source_root
        Kameleon.env.repositories_path
      end

      desc "list", "Lists all available templates"
      def list
        Kameleon.ui.info "The following templates are available in " \
                         "#{ Kameleon.env.repositories_path }:"
        Utils.list_recipes(Kameleon.env.repositories_path)
      end

      desc "import [TEMPLATE_NAME]", "Imports the given template"
      method_option :global, :type => :hash ,
                    :default => {},  :aliases => "-g",
                    :desc => "Set custom global variables."
      def import(template_name)
        Kameleon.env.root_dir = Kameleon.env.repositories_path
        template_path = File.join(Kameleon.env.repositories_path, template_name)
        unless template_name.end_with? '.yaml'
          template_path = template_path + '.yaml'
        end
        # Manage global as it is not passed to env by default
        if options[:global]
           Kameleon.env.global.merge!(options[:global])
        end
        begin
          tpl = RecipeTemplate.new(template_path)
          tpl.resolve! :strict => false
        rescue
          raise if Kameleon.ui.level("verbose")
          raise TemplateNotFound, "Template '#{template_name}' invalid (try" \
              " --verbose) or not found. To see all templates, run the command "\
              "`kameleon template list`"
        else
          tpl.all_files.each do |path|
            relative_path = path.relative_path_from(Kameleon.env.repositories_path)
            dst = File.join(Kameleon.env.workspace, relative_path)
            copy_file(path, dst)
          end
        end
      end

      desc "info [TEMPLATE_NAME]", "Display detailed information about a template"
      method_option :global, :type => :hash ,
                    :default => {},  :aliases => "-g",
                    :desc => "Set custom global variables."
      def info(template_name)
        Kameleon.env.root_dir = Kameleon.env.repositories_path
        template_path = File.join(Kameleon.env.repositories_path, template_name)
        unless template_name.end_with? '.yaml'
          template_path = template_path + '.yaml'
        end
        # Manage global as it is not passed to env by default
        if options[:global]
           Kameleon.env.global.merge!(options[:global])
        end
        tpl = RecipeTemplate.new(template_path)
        tpl.resolve! :strict => false
        tpl.display_info(false)
      end
      map %w(-h --help) => :help
      map %w(ls) => :list
    end
  end


  class Main < Thor
    include Thor::Actions

    register CLI::Repository, 'repository', 'repository', 'Manages set of remote git repositories'
    # register CLI::Recipe, 'recipe', 'recipe', 'Manages the local recipes'
    register CLI::Template, 'template', 'template', 'Lists and imports templates'

    class_option :color, :type => :boolean, :default => Kameleon.default_values[:color],
                 :desc => "Enables colorization in output"
    class_option :verbose, :type => :boolean, :default => Kameleon.default_values[:verbose],
                 :desc => "Enables verbose output for kameleon users"
    class_option :debug, :type => :boolean, :default => Kameleon.default_values[:debug],
                 :desc => "Enables debug output for kameleon developpers"
    class_option :script, :type => :boolean, :default => Kameleon.default_values[:script],
                 :desc => "Never prompts for user intervention",
                 :aliases => "-s"
    map %w(-h --help) => :help

    desc "version", "Prints the Kameleon's version information"
    def version
      puts "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version

    def self.source_root
      Kameleon.env.repositories_path
    end

    desc "list", "Lists all defined recipes in the current directory"
    def list
      Utils.list_recipes(Kameleon.env.workspace)
    end
    map %w(ls) => :list

    desc "new [RECIPE_PATH] [TEMPLATE_NAME]", "Creates a new recipe"
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    def new(recipe_name, template_name)
      Kameleon.env.root_dir = Kameleon.env.repositories_path
      unless template_name.end_with? '.yaml'
        template_name = template_name + '.yaml'
      end

      unless recipe_name.end_with? '.yaml'
        recipe_name = recipe_name + '.yaml'
      end

      if recipe_name == template_name
        fail RecipeError, "Recipe path should be different from template name"
      end

      template_path = File.join(Kameleon.env.repositories_path, template_name)

      recipe_path = Pathname.new(Kameleon.env.workspace).join(recipe_name).to_s

      begin
        tpl = Kameleon::RecipeTemplate.new(template_path)
        tpl.resolve! :strict => false
      rescue
          raise if Kameleon.ui.level("verbose")
          raise TemplateNotFound, "Template '#{template_name}' invalid (try" \
              " --verbose) or not found. To see all templates, run the command "\
              "`kameleon template list`"

      else
        tpl.all_files.each do |path|
          relative_path = path.relative_path_from(Kameleon.env.repositories_path)
          dst = File.join(Kameleon.env.workspace, relative_path)
          copy_file(path, dst)
        end
        Dir::mktmpdir do |tmp_dir|
          recipe_temp = File.join(tmp_dir, File.basename(recipe_path))
          ## copying recipe
          File.open(recipe_temp, 'w+') do |file|
            extend_erb_tpl = File.join(Kameleon.erb_dirpath, "extend.erb")
            erb = ERB.new(File.open(extend_erb_tpl, 'rb') { |f| f.read })
            result = erb.result(binding)
            file.write(result)
          end
          copy_file(recipe_temp, recipe_path)
        end
      end
    end

    desc "info [RECIPE_PATH]", "Display detailed information about a recipe"
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    method_option :from_cache, :type => :string ,
                  :default => nil,
                  :desc => "Get info from a persistent cache tar file (ignore recipe path)"
    method_option :dryrun, :type => :boolean ,
                  :default => false,
                  :desc => "Show the build sequence but do not actually build"
    method_option :dag, :type => :boolean ,
                  :default => false,
                  :desc => "Show a DAG of the build sequence"
    method_option :file, :type => :string ,
                  :default => "/tmp/kameleon.dag",
                  :desc => "DAG output filename"
    method_option :format, :type => :string ,
                  :desc => "DAG GraphViz format"
    method_option :relative, :type => :boolean ,
                  :default => false,
                  :desc => "Make pathnames relative to the current working directory"

    def info(*recipe_paths)
      if recipe_paths.length == 0 && !options[:from_cache].nil?
        unless File.file?(options[:from_cache])
          raise CacheError, "The specified cache file "\
                            "\"#{options[:from_cache]}\" do not exists"
        end
        Kameleon.ui.info("Using the cached recipe")
        @cache = Kameleon::Persistent_cache.instance
        @cache.cache_path = options[:from_cache]
      end
      dag = nil
      color = 0
      recipe_paths.each do |path|
        recipe = Kameleon::Recipe.new(path)
        if options[:dryrun]
          Kameleon::Engine.new(recipe, options).dryrun
        elsif options[:dag]
          dag = Kameleon::Engine.new(recipe, options).dag(dag, color)
          color += 1
        else
          recipe.resolve!
          recipe.display_info(options[:relative])
        end
      end
      if options[:dag]
        format = "canon"
        if options[:format]
          if GraphViz::Constants::FORMATS.include?(options[:format])
            format = options[:format]
          else
            Kameleon.ui.warn("Unknown GraphViz format #{options[:format]}, fall back to #{format}")
          end
        else
          options[:file].match(/^.+\.([^\.]+)$/) do |f|
            if GraphViz::Constants::FORMATS.include?(f[1])
              format = f[1]
            end
          end
        end
        dag.output( :"#{format}" => options[:file] )
        Kameleon.ui.info("Generated GraphViz #{format} file: #{options[:file]}")
      end
    end

    desc "build [RECIPE_PATH]", "Builds the appliance from the given recipe"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Sets the build directory path"
    method_option :clean, :type => :boolean ,
                  :default => false,
                  :desc => "Runs the command `kameleon clean` first"
    method_option :from_checkpoint, :type => :string ,
                  :default => nil,
                  :desc => "Uses specific checkpoint to build the image. " \
                           "Default value is the last checkpoint."
    method_option :enable_checkpoint, :type => :boolean ,
                  :default => false,
                  :desc => "Enables checkpoint [experimental]"
    method_option :list_checkpoints, :type => :boolean , :aliases => "--checkpoints",
                  :default => false,
                  :desc => "Lists all availables checkpoints"
    method_option :enable_cache, :type => :boolean,
                  :default => false,
                  :desc => "Generates a persistent cache for the appliance."
    method_option :cache_path, :type => :string ,
                  :default => nil,
                  :desc => "Sets the cache directory path"
    method_option :from_cache, :type => :string ,
                  :default => nil,
                  :desc => "Uses a persistent cache tar file to build the image."
    method_option :cache_archive_compression, :type => :string ,
                  :enum => ["none", "gzip", "bz2", "xz"],
                  :default => "gzip",
                  :desc => "Set the persistent cache tar file compression."
    method_option :polipo_path, :type => :string ,
                  :default => nil,
                  :desc => "Full path of the polipo binary to use for the persistent cache."
    method_option :proxy, :type => :string, :default => "",
                  :desc => "Specifies the hostname and port number of an HTTP " \
                           "proxy; it should have the form 'host:port'"
    method_option :proxy_credentials, :type => :string, :default => "",
                  :desc => "Specifies the username and password if the parent "\
                           "proxy requires authorisation it should have the "\
                           "form 'username:password'"
    method_option :proxy_offline, :type => :boolean ,
                  :default => false, :aliases => "--offline",
                  :desc => "Prevents Polipo from contacting remote servers"
    method_option :global, :type => :hash,
                  :default => {}, :aliases => "-g",
                  :desc => "Set custom global variables."
    def build(recipe_path=nil)
      if recipe_path.nil? && !options[:from_cache].nil?
        unless File.file?(options[:from_cache])
          raise CacheError, "The specified cache file "\
                            "\"#{options[:from_cache]}\" do not exists"
        end
        Kameleon.ui.info("Using the cached recipe")
        @cache = Kameleon::Persistent_cache.instance
        @cache.cache_path = options[:from_cache]
        recipe_path =  @cache.get_recipe
      end
      raise BuildError, "A recipe file or a persistent cache archive " \
                        "is required to run this command." if recipe_path.nil?
      if options[:clean]
        opts = Hash.new.merge options
        opts[:lazyload] = false
        opts[:fail_silently] = true
        engine = Kameleon::Engine.new(Recipe.new(recipe_path), opts)
        engine.clean(:with_checkpoint => true)
      elsif options[:list_checkpoints]
        Kameleon.ui.level = "error"
        engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
        engine.pretty_checkpoints_list
      else
        engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
        Kameleon.ui.info("Starting build recipe '#{recipe_path}'")
        start_time = Time.now.to_i
        engine.build
        total_time = Time.now.to_i - start_time
        Kameleon.ui.info("")
        Kameleon.ui.info("Successfully built '#{recipe_path}'")
        Kameleon.ui.info("Total duration : #{total_time} secs")
      end
    end

    desc "commands", "Lists all available commands", :hide => true
    def commands
      puts Main.all_commands.keys - ["commands", "completions"]
    end

    desc "source_root", "Prints the kameleon directory path", :hide => true
    def source_root
      puts Kameleon.source_root
    end

    def initialize(*args)
      super
      self.options ||= {}
      Kameleon.env = Kameleon::Environment.new(self.options)
      if !$stdout.tty? or !options["color"]
        Thor::Base.shell = Thor::Shell::Basic
      end
      Kameleon.ui = Kameleon::UI::Shell.new(self.options)

      if (self.options["debug"] or ENV['KAMELEON_DEBUG'])
        Kameleon.ui.level = "debug"
      elsif self.options["verbose"]
        Kameleon.ui.level = "verbose"
      end
      Kameleon.ui.verbose("The level of output is set to #{Kameleon.ui.level}")

      opts = args[1]
      cmd_name = args[2][:current_command].name
      if opts.include? "--help" or opts.include? "-h"
        Main.command_help(Kameleon.ui.shell, cmd_name)
        raise Kameleon::Exit
      end
    end

    def self.start(*)
      super
    rescue Exception => e
      Kameleon.ui = Kameleon::UI::Shell.new
      raise e
    end

  end

end
