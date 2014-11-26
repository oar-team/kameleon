require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

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

      register CLI::Repository, 'repository', 'repository', 'Manages set of remote git repositories'

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
      def import(template_name)
        Kameleon.env.root_dir = Kameleon.env.repositories_path
        template_path = File.join(Kameleon.env.repositories_path, template_name)
        unless template_name.end_with? '.yaml'
          template_path = template_path + '.yaml'
        end
        begin
          tpl = RecipeTemplate.new(template_path)
        rescue
          raise TemplateNotFound, "Template '#{template_name}' not found. " \
                                  "To see all templates, run the command "\
                                  "`kameleon template ls`"
        else
          files2copy = tpl.base_recipes_files + tpl.files
          files2copy.each do |path|
            relative_path = path.relative_path_from(Kameleon.env.repositories_path)
            dst = File.join(Kameleon.env.workspace, relative_path)
            copy_file(path, dst)
          end
        end
      end

      desc "info [TEMPLATE_NAME]", "Display detailed information about a template"
      def info(template_name)
        Kameleon.env.root_dir = Kameleon.env.repositories_path
        template_path = File.join(Kameleon.env.repositories_path, template_name)
        unless template_name.end_with? '.yaml'
          template_path = template_path + '.yaml'
        end
        tpl = RecipeTemplate.new(template_path)
        tpl.display_info
      end
      map %w(-h --help) => :help
      map %w(ls) => :list
    end
  end


  class Main < Thor
    include Thor::Actions

    # register CLI::Recipe, 'recipe', 'recipe', 'Manages the local recipes'
    register CLI::Template, 'template', 'template', 'Lists and imports templates'

    class_option :color, :type => :boolean, :default => Kameleon.default_values[:color],
                 :desc => "Enables colorization in output"
    class_option :debug, :type => :boolean, :default => Kameleon.default_values[:debug],
                 :desc => "Enables debug output"
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
    def new(recipe_path, template_name)
      Kameleon.env.root_dir = Kameleon.env.repositories_path
      unless template_name.end_with? '.yaml'
        template_name = template_name + '.yaml'
      end

      unless recipe_path.end_with? '.yaml'
        recipe_path = recipe_path + '.yaml'
      end

      if recipe_path == template_name
        fail RecipeError, "Recipe path should be different from template name"
      end

      template_path = File.join(Kameleon.env.repositories_path, template_name)

      recipe_path = Pathname.new(Kameleon.env.workspace).join(recipe_path).to_path

      begin
        tpl = Kameleon::RecipeTemplate.new(template_path)
      rescue
        raise TemplateNotFound, "Template '#{template_name}' not found. " \
                                "To see all templates, run the command "\
                                "`kameleon templates`"
      else
        files2copy = tpl.base_recipes_files + tpl.files
        files2copy.each do |path|
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
    def info(recipe_path)
      recipe = Kameleon::Recipe.new(recipe_path)
      recipe.display_info
    end

    desc "build [[RECIPE_PATH]]", "Builds the appliance from the given recipe"
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
    method_option :enable_cache, :type => :boolean,
                  :default => false,
                  :desc => "Generates a persistent cache for the appliance."
    method_option :cache_path, :type => :string ,
                  :default => nil,
                  :desc => "Sets the cache directory path"
    method_option :from_cache, :type => :string ,
                  :default => nil,
                  :desc => "Uses a persistent cache tar file to build the image."
    method_option :proxy_path, :type => :string ,
                  :default => nil,
                  :desc => "Full path of the proxy binary to use for the persistent cache."

    def build(recipe_path=nil)
      if recipe_path.nil? && !options[:from_cache].nil?
        Kameleon.ui.info("Using the cached recipe")
        @cache = Kameleon::Persistent_cache.instance
        @cache.cache_path = options[:from_cache]
        recipe_path =  @cache.get_recipe
      end
      raise BuildError, "A recipe file or a persistent cache archive " \
                        "is required to run this command." if recipe_path.nil?
      clean(recipe_path) if options[:clean]
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      Kameleon.ui.info("Starting build recipe '#{recipe_path}'")
      start_time = Time.now.to_i
      engine.build
      total_time = Time.now.to_i - start_time
      Kameleon.ui.info("")
      Kameleon.ui.info("Successfully built '#{recipe_path}'")
      Kameleon.ui.info("Total duration : #{total_time} secs")
    end

    desc "checkpoints [RECIPE_PATH]", "Lists all availables checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Set the build directory path"
    def checkpoints(recipe_path)
      Kameleon.ui.level = "error"
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), options)
      engine.pretty_checkpoints_list
    end

    desc "clean [RECIPE_PATH]", "Cleans all contexts and removing the checkpoints"
    method_option :build_path, :type => :string ,
                  :default => nil, :aliases => "-b",
                  :desc => "Sets the build directory path"
    def clean(recipe_path)
      opts = Hash.new.merge options
      opts[:lazyload] = false
      opts[:fail_silently] = true
      engine = Kameleon::Engine.new(Recipe.new(recipe_path), opts)
      engine.clean(:with_checkpoint => true)
    end
    map %w(clear) => :clean

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
      Kameleon.ui.level = "debug" if self.options["debug"]
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
