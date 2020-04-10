require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'
require 'tempfile'
require 'graphviz'

module Kameleon

  module CLI

    class Repository < Thor
      include Thor::Actions

      desc "add <NAME> <GIT_URL>", "Adds a new repository named <NAME> cloned from at <GIT_URL>."
      method_option :branch, :type => :string ,
                    :default => nil,
                    :desc => "checkout <BRANCH>",
                    :aliases => "-b"
      def add(name, url)
        Kameleon::Repository.add(name, url, options)
      end

      desc "list", "Lists available repositories."
      method_option :git, :type => :boolean,
                    :default => true,
                    :desc => "show the git repository and branch each repository comes from"
      def list
        Kameleon::Repository.list(options)
      end

      desc "update <NAME>", "Updates repository named <NAME> from git"
      def update(name)
        Kameleon::Repository.update(name)
      end

      desc "remove <NAME>", "Remove repository named <NAME>"
      def remove(name)
        Kameleon::Repository.remove(name)
      end
      map %w(ls) => :list
      map %w(rm) => :remove
    end


    class Template < Thor
      include Thor::Actions

      def self.source_root
        Kameleon.env.repositories_path
      end

      desc "list", "Lists all available templates"
      def list
        Kameleon.ui.info "The following templates are available in " \
                         "#{ Kameleon.env.repositories_path }:"
        Utils.list_recipes(Kameleon.env.repositories_path)
      end

      desc "import <TEMPLATE_NAME>", "Imports the given template"
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

      desc "info <TEMPLATE_NAME>", "Display detailed information about a template"
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
      map %w(ls) => :list
    end
  end


  class Main < Thor
    include Thor::Actions

    desc 'repository <SUBCOMMAND>', 'Manages repositories of recipes'
    subcommand 'repository', CLI::Repository
    desc 'template <SUBCOMMAND>', 'Lists and imports templates'
    subcommand 'template', CLI::Template

    class_option :color, :type => :boolean, :default => Kameleon.default_values[:color],
                 :desc => "Enables colorization in output"
    class_option :verbose, :type => :boolean, :default => Kameleon.default_values[:verbose],
                 :desc => "Enables verbose output for kameleon users"
    class_option :debug, :type => :boolean, :default => Kameleon.default_values[:debug],
                 :desc => "Enables debug output for kameleon developpers"
    class_option :script, :type => :boolean, :default => Kameleon.default_values[:script],
                 :desc => "Never prompts for user intervention",
                 :aliases => "-s"

    desc "version", "Prints the Kameleon's version information"
    def version
      puts "Kameleon version #{Kameleon::VERSION}"
    end

    def self.source_root
      Kameleon.env.repositories_path
    end

    desc "list", "Lists all defined recipes in the current directory"
    def list
      Utils.list_recipes(Kameleon.env.workspace)
    end

    desc "new <RECIPE_PATH> <TEMPLATE_NAME>", "Creates a new recipe from template <TEMPLATE_NAME>"
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
            message="Use extend ERB template: "
            extend_erb_tpl = [
              Kameleon.env.repositories_path.join(template_name + ".erb"),
              Pathname.new(template_name).dirname.ascend.to_a.push(Pathname.new("")).map do |p|
                Kameleon.env.repositories_path.join(p, ".kameleon-extend.yaml.erb")
              end,
              Pathname.new(Kameleon.erb_dirpath).join("extend.yaml.erb")
            ].flatten.find do |f|
              Kameleon.ui.verbose(message + f.to_s)
              message = "-> Not found, fallback: "
              File.readable?(f)
            end 
            erb = ERB.new(File.open(extend_erb_tpl, 'rb') { |f| f.read })
            result = erb.result(binding)
            file.write(result)
          end
          copy_file(recipe_temp, recipe_path)
        end
      end
    end

    desc "info <RECIPE_PATH>", "Display detailed information about a recipe"
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    method_option :from_cache, :type => :string ,
                  :default => nil,
                  :desc => "Get info from a persistent cache tar file (ignore recipe path)"
    method_option :dryrun, :type => :boolean ,
                  :default => false,
                  :desc => "Show the build sequence but do not actually build"
    method_option :relative, :type => :boolean ,
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
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    method_option :file, :type => :string ,
                  :default => "/tmp/kameleon.dag",
                  :desc => "DAG output filename"
    method_option :format, :type => :string ,
                  :desc => "DAG GraphViz format"
    method_option :relative, :type => :boolean ,
                  :default => false,
                  :desc => "Make pathnames relative to the current working directory"
    method_option :recipes_only, :type => :boolean ,
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

    desc "dryrun <RECIPE_PATH>", "Show the steps the build would process"
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    method_option :relative, :type => :boolean ,
                  :default => false,
                  :desc => "Make pathnames relative to the current working directory"
    def dryrun(*recipe_paths)
      raise ArgumentError if recipe_paths.empty?
      recipe_paths.each do |path|
        recipe = Kameleon::Recipe.new(path)
        Kameleon::Engine.new(recipe, options.dup.merge({no_create_build_dir: true}).freeze).dryrun
      end
    end

    desc "export <RECIPE_PATH> <EXPORT_PATH>", "Export the given recipe with its steps and data to a given directory"
    method_option :global, :type => :hash ,
                  :default => {},  :aliases => "-g",
                  :desc => "Set custom global variables."
    method_option :add, :type => :boolean ,
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
      if File.exists?(dest_path)
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

    desc "build <RECIPE_PATH>", "Builds the appliance from the given recipe"
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

    map %w(-v --version) => :version
    map %w(ls) => :list
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
