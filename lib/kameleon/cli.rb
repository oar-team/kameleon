require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'
require 'tempfile'
require 'graphviz'

module Kameleon

  module CLI

    class Repository < Thor
      include Thor::Actions

      desc "add <NAME> <GIT_URL>", "Add a new repository named <NAME> cloned from <GIT_URL>"
      method_option :branch, :type => :string,
                    :default => nil,
                    :desc => "checkout <BRANCH>",
                    :aliases => "-b"
      def add(name, url)
        Kameleon::Repository.add(name, url, options)
      end

      desc "list", "List available repositories"
      method_option :git, :type => :boolean,
                    :default => true,
                    :desc => "show the git repository and branch each repository comes from"
      def list
        Kameleon::Repository.list(options)
      end

      desc "update <NAME>", "Update repository named <NAME> from git"
      def update(name)
        Kameleon::Repository.update(name)
      end

      desc "remove <NAME>", "Remove repository named <NAME>"
      def remove(name)
        Kameleon::Repository.remove(name)
      end

      desc "commands", "List all available commands", :hide => true
      def commands
        puts Repository.all_commands.keys - ["commands"]
      end

      map %w(ls) => :list
      map %w(rm) => :remove
      map %w(completions) => :commands
    end


    class Template < Thor
      include Thor::Actions

      def self.source_root
        Kameleon.env.repositories_path
      end

      desc "list", "List all available templates"
      method_option :progress, :type => :boolean, :default => true,
                    :desc => "Show progress bar while resolving templates",
                    :aliases => "-p"
      method_option :filter, :type => :string, :default => nil,
                    :desc => "Filter templates with the given regexp",
                    :aliases => "-f"
      def list
        Kameleon.ui.shell.say "Recipe templates available in: ", :red, false
        Kameleon.ui.shell.say Kameleon.env.repositories_path.to_s, :yellow
        Utils.list_recipes(Kameleon.env.repositories_path, options[:filter], options[:progress], true)
      end

      desc "import <TEMPLATE_NAME>", "Import the given template"
      method_option :global, :type => :hash,
                    :default => {},  :aliases => "-g",
                    :desc => "Set custom global variables"
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
            chmod(dst, File.stat(path).mode, {:verbose=>false})
          end
        end
      end

      desc "info <TEMPLATE_NAME>", "Display detailed information about a template"
      method_option :global, :type => :hash,
                    :default => {},  :aliases => "-g",
                    :desc => "Set custom global variables"
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

      desc "erb <PATH>", "Create a extend recipe ERB file"
      def erb(path)
        if File.directory?(path)
          erb_file = Pathname.new(path).join(Kameleon.default_values[:extend_yaml_erb])
        elsif File.file?(path) and path.end_with?(".yaml")
          erb_file = Pathname.new(path.gsub(%r{^(.+?/)?([^/]+?)(\.yaml)?$},'\1.\2') + Kameleon.default_values[:extend_yaml_erb])
        else
          fail KameleonError, "Invalid path '#{path}', please give a path to a yaml file or a directory"
        end
        Kameleon.ui.verbose("Create extend recipe ERB '#{erb_file}'")
        copy_file(Pathname.new(Kameleon.erb_dirpath).join("extend.yaml.erb"), erb_file)
      end

      desc "commands", "List all available commands", :hide => true
      def commands
        puts Template.all_commands.keys - ["commands"]
      end

      map %w(ls) => :list
      map %w(completions) => :commands
    end
  end


  class Main < Thor
    include Thor::Actions

    desc 'repository <SUBCOMMAND>', 'Manage repositories of recipes'
    subcommand 'repository', CLI::Repository
    desc 'template <SUBCOMMAND>', 'List and import templates'
    subcommand 'template', CLI::Template

    class_option :color, :type => :boolean, :default => Kameleon.default_values[:color],
                 :desc => "Enable colorization in output"
    class_option :verbose, :type => :boolean, :default => Kameleon.default_values[:verbose],
                 :desc => "Enable verbose output for kameleon users"
    class_option :debug, :type => :boolean, :default => Kameleon.default_values[:debug],
                 :desc => "Enable debug output for kameleon developers"
    class_option :script, :type => :boolean, :default => Kameleon.default_values[:script],
                 :desc => "Never prompt for user intervention",
                 :aliases => "-s"

    desc "version", "Print the Kameleon's version information"
    def version
      puts "Kameleon version #{Kameleon::VERSION}"
    end

    def self.source_root
      Kameleon.env.repositories_path
    end

    desc "list", "List all defined recipes in the current directory"
    method_option :progress, :type => :boolean, :default => false,
                  :desc => "Show progress bar while resolving recipes",
                  :aliases => "-p"
    method_option :filter, :type => :string, :default => nil,
                  :desc => "Filter recipes with the given regexp",
                  :aliases => "-f"
    def list
      Kameleon.ui.shell.say "Workspace recipes:", :red
      Utils.list_recipes(Kameleon.env.workspace, options[:filter], options[:progress])
    end

    desc "new <RECIPE_PATH> <TEMPLATE_NAME>", "Create a new recipe from template <TEMPLATE_NAME>"
    method_option :global, :type => :hash,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables"
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
          chmod(dst, File.stat(path).mode, {:verbose=>false})
        end
        Dir::mktmpdir do |tmp_dir|
          recipe_temp = File.join(tmp_dir, File.basename(recipe_path))
          ## copying recipe
          File.open(recipe_temp, 'w+') do |file|
            message="Try and use extend recipe ERB: "
            extend_yaml_erb_list = Pathname.new(template_name).dirname.ascend.to_a.map do |p|
              Kameleon.env.repositories_path.join(p, Kameleon.default_values[:extend_yaml_erb])
            end
            extend_yaml_erb_list.unshift(Kameleon.env.repositories_path.join(template_name.gsub(%r{^(.+?/)?([^/]+?)(\.yaml)?$},'\1.\2') + Kameleon.default_values[:extend_yaml_erb]))
            extend_yaml_erb_list.push(Pathname.new(Kameleon.erb_dirpath).join("extend.yaml.erb"))
            extend_yaml_erb = extend_yaml_erb_list.find do |f|
              Kameleon.ui.verbose(message + f.to_s)
              message = "-> Not found, fallback: "
              File.readable?(f)
            end 
            Kameleon.ui.debug("Open ERB file: '#{extend_yaml_erb}'")
            result = ERB.new(File.open(extend_yaml_erb, 'rb') { |f| f.read }).result(binding)
            file.write(result)
          end
          copy_file(recipe_temp, recipe_path)
        end
      end
    end

    desc "info <RECIPE_PATH>", "Display detailed information about a recipe"
    method_option :global, :type => :hash,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables"
    method_option :from_cache, :type => :string,
                  :default => nil,
                  :desc => "Get info from a persistent cache tar file (ignore recipe path)"
    method_option :relative, :type => :boolean,
                  :default => false,
                  :desc => "Make pathnames relative to the current working directory"
    def info(*recipe_paths)
      if recipe_paths.empty?
        if options[:from_cache].nil?
          raise ArgumentError
        else
          unless File.file?(options[:from_cache])
            raise CacheError, "The specified cache file "\
                              "\"#{options[:from_cache]}\" do not exists"
          end
          Kameleon.ui.info("Using the cached recipe")
          @cache = Kameleon::Persistent_cache.instance
          @cache.cache_path = options[:from_cache]
        end
      else
        recipe_paths.each do |path|
          recipe = Kameleon::Recipe.new(path)
          recipe.resolve!
          recipe.display_info(options[:relative])
        end
      end
    end

    desc "dag <RECIPE_PATH> [<RECIPE_PATH> [<...>]]", "Draw a DAG of the steps to build one or more recipes"
    method_option :global, :type => :hash,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables"
    method_option :file, :type => :string,
                  :default => "/tmp/kameleon.dag",
                  :desc => "DAG output filename"
    method_option :format, :type => :string,
                  :desc => "DAG GraphViz format"
    method_option :relative, :type => :boolean,
                  :default => false,
                  :desc => "Make pathnames relative to the current working directory"
    method_option :recipes_only, :type => :boolean,
                  :default => false,
                  :desc => "Show recipes only (mostly useful to display multiple recipes inheritance)"
    def dag(*recipe_paths)
      raise ArgumentError if recipe_paths.empty?
      color = 0
      recipes_dag = nil
      recipe_paths.each do |path|
        recipe = Kameleon::Recipe.new(path)
        recipes_dag = Kameleon::Engine.new(recipe, options.dup.merge({no_create_build_dir: true}).freeze).dag(recipes_dag, color, options[:recipes_only])
        color += 1
      end
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
      recipes_dag.output( :"#{format}" => options[:file] )
      Kameleon.ui.info("Generated GraphViz #{format} file: #{options[:file]}")
    end

    desc "export <RECIPE_PATH> <EXPORT_PATH>", "Export the given recipe with its steps and data to a given directory"
    method_option :global, :type => :hash,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables"
    method_option :add, :type => :boolean,
                  :default => false,  :aliases => "-A",
                  :desc => "export recipe and steps to an existing directory (this may overwrite some existing files)"
    def export(recipe_path,dest_path)
      unless recipe_path.end_with? '.yaml'
        recipe_path = recipe_path + '.yaml'
      end
      # Manage global as it is not passed to env by default
      if options[:global]
         Kameleon.env.global.merge!(options[:global])
      end
      recipe = Recipe.new(recipe_path)
      recipe.resolve! :strict => false
      recipe.all_files.uniq.each do |path|
        relative_path = path.relative_path_from(Kameleon.env.workspace)
          if relative_path.fnmatch("../*")
            raise if Kameleon.ui.level("verbose")
            raise ExportError, "Recipe '#{recipe_path}' depends on a file" \
                " outside of the current directory: '#{relative_path.to_s}'"
          end
      end
      Kameleon.ui.info("Export recipe #{recipe_path} to directory: #{dest_path}")
      if File.exist?(dest_path)
        unless options[:add]
          raise if Kameleon.ui.level("verbose")
          raise ExportError, "Target export directory '#{dest_path}' already "\
              "exists, use the --add option if you really want to export the "\
              "recipe files to it (this may overwrite some existing files)"
        end
      else
        FileUtils.mkdir_p(dest_path)
      end
      recipe.all_files.uniq.each do |path|
        relative_path = path.relative_path_from(Kameleon.env.workspace)
        dst = File.join(dest_path, relative_path)
        copy_file(path, dst)
      end
    end

    desc "build <RECIPE_PATH>", "Build the appliance from the given recipe"
    method_option :build_path, :type => :string,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    method_option :clean, :type => :boolean,
                  :default => false,
                  :desc => "Run the command `kameleon clean` first"
    method_option :dryrun, :type => :boolean, :aliases => "-d",
                  :default => false,
                  :desc => "Dry run, only show what would run"
    method_option :relative, :type => :boolean,
                  :default => false,
                  :desc => "Make dryrun show pathnames relative to the current working directory"
    method_option :from_checkpoint, :type => :string, :aliases => "-F",
                  :default => nil,
                  :desc => "Restart the build from a specific checkpointed step, instead of the latest one"
    method_option :begin_checkpoint, :type => :string, :aliases => "-B",
                  :default => nil,
                  :desc => "Only create checkpoints after the given step"
    method_option :end_checkpoint, :type => :string, :aliases => "-E",
                  :default => nil,
                  :desc => "Do not create checkpoints after the given step"
    method_option :enable_checkpointing, :type => :boolean, :aliases => "-c",
                  :default => false,
                  :desc => "Enable creating and using checkpoints"
    method_option :microstep_checkpoints, :type => :string,
                  :enum => ["first", "all"],
                  :default => "all",
                  :desc => "Create checkpoint of the first microstep only, or all"
    method_option :list_checkpoints, :type => :boolean, :aliases => "-l",
                  :default => false,
                  :desc => "List availables checkpoints"
    method_option :enable_cache, :type => :boolean, :aliases => "-C",
                  :default => false,
                  :desc => "Generate a persistent cache for the appliance"
    method_option :cache_path, :type => :string,
                  :default => nil,
                  :desc => "Set the cache directory path"
    method_option :from_cache, :type => :string,
                  :default => nil,
                  :desc => "Use a persistent cache tar file to build the image"
    method_option :cache_archive_compression, :type => :string,
                  :enum => ["none", "gzip", "bz2", "xz"],
                  :default => "gzip",
                  :desc => "Set the persistent cache tar file compression"
    method_option :polipo_path, :type => :string,
                  :default => nil,
                  :desc => "Full path of the polipo binary to use for the persistent cache"
    method_option :proxy, :type => :string, :default => "",
                  :desc => "HTTP proxy address and port (expected format is hostname:port)"
    method_option :proxy_credentials, :type => :string, :default => "",
                  :desc => "Username and password if required by the parent proxy (expected format is username:password)"
    method_option :proxy_offline, :type => :boolean,
                  :default => false,
                  :desc => "Prevent Polipo from contacting remote servers"
    method_option :global, :type => :hash,
                  :default => {}, :aliases => "-g",
                  :desc => "Set custom global variables"
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
      if options[:dryrun]
        Kameleon::Engine.new(Kameleon::Recipe.new(recipe_path), options.dup.merge({no_create_build_dir: true}).freeze).dryrun
      elsif options[:clean]
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
        Kameleon.ui.info("Total duration: #{total_time} secs")
      end
    end

    desc "commands", "List all available commands", :hide => true
    def commands(context="main")
      Kameleon.ui.debug("Commands for '#{context}':")
      case context
      when "main"
        puts Main.all_commands.keys - ["commands"]
      when "repository"
        invoke CLI::Repository, "commands", [], []
      when "template"
        invoke CLI::Template, "commands", [], []
      end
    end

    desc "source_root", "Print the kameleon directory path", :hide => true
    def source_root
      puts Kameleon.source_root
    end

    map %w(-v --version) => :version
    map %w(ls) => :list
    map %w(completions) => :commands

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
    end

    def self.start(*args)
      # `kameleon build -h` does not work without the following, except for subcommands...
      # Ref: https://stackoverflow.com/a/49044225/6431461
      if (Thor::HELP_MAPPINGS & ARGV).any? and subcommands.grep(/^#{ARGV[0]}/).empty?
        Kameleon.ui.debug("Apply workaround to handle the help command in #{ARGV}")
        Thor::HELP_MAPPINGS.each do |cmd|
          if match = ARGV.delete(cmd)
            ARGV.unshift match
          end
        end
      end
      super
    rescue Exception => e
      Kameleon.ui = Kameleon::UI::Shell.new
      raise e
    end

  end

end
