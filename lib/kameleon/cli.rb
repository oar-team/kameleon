require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

module Kameleon

  module CLI
    class Recipe < Thor

      desc "new [RECIPE_NAME] [[TEMPLATE_NAME]]", "Creates a new recipe"
      def new(recipe_name, template_name)
        if recipe_name == template_name
          fail RecipeError, "Recipe name should be different from template name"
        end
        templates_path = Kameleon.env.templates_path
        template_path = File.join(templates_path, template_name) + '.yaml'
        begin
          tpl = RecipeTemplate.new(template_path)
        rescue
          raise TemplateNotFound, "Template '#{template_name}' not found. " \
                                  "To see all templates, run the command "\
                                  "`kameleon templates`"
        else
          files2copy = tpl.base_recipes_files + tpl.files
          files2copy.each do |path|
            relative_path = path.relative_path_from(Kameleon.env.templates_path)
            dst = File.join(Kameleon.env.workspace, relative_path)
            copy_file(path, dst)
          end
          Dir::mktmpdir do |tmp_dir|
            recipe_path = File.join(tmp_dir, recipe_name + '.yaml')
            ## copying recipe
            File.open(recipe_path, 'w+') do |file|
              extend_erb_tpl = File.join(Kameleon.default_templates_path, "extend.erb")
              erb = ERB.new(File.open(extend_erb_tpl, 'rb') { |f| f.read })
              result = erb.result(binding)
              file.write(result)
            end
            recipe_dst = File.join(Kameleon.env.workspace, recipe_name + '.yaml')
            copy_file(recipe_path, Pathname.new(recipe_dst))
          end
        end
      end
    end

    class Template < Thor

      desc "list", "Lists all defined templates"
      def list
        puts "The following templates are available in " \
                   "#{ Kameleon.env.repositories_path }:"
        templates_hash = []
        Dir["#{Kameleon.env.repositories_path}/*"].each do |repository_path|
          next unless File.directory?(repository_path)
          repository = File.basename(repository_path)
          templates_path = File.join(repository_path, "/")
          all_yaml_files = Dir["#{templates_path}**/*.yaml"]
          steps_files = Dir["#{templates_path}steps/**/*.yaml"]
          steps_files = steps_files + Dir["#{templates_path}.steps/**/*.yaml"]
          templates_files = all_yaml_files - steps_files
          templates_files.each do |f|
            begin
            recipe = RecipeTemplate.new(f)
            templates_hash.push({
              "name" => "#{repository}/#{f.gsub(templates_path, '').chomp('.yaml')}",
              "description" => recipe.metainfo['description'],
            })
            rescue => e
              raise e if Kameleon.env.debug
            end
          end
        end
        unless templates_hash.empty?
          templates_hash = templates_hash.sort_by{ |k| k["name"] }
          name_width = templates_hash.map { |k| k['name'].size }.max
          desc_width = Kameleon.ui.shell.terminal_width - name_width - 3
          desc_width = (80 - name_width - 3) if desc_width < 0
        end
        tp(templates_hash,
          {"name" => {:width => name_width}},
          { "description" => {:width => desc_width}})
      end


      desc "import [TEMPLATE_NAME]", "Imports the given template"
      def import(template_name)
        templates_path = Kameleon.env.templates_path
        template_path = File.join(templates_path, template_name) + '.yaml'
        begin
          tpl = RecipeTemplate.new(template_path)
        rescue
          raise TemplateNotFound, "Template '#{template_name}' not found. " \
                                  "To see all templates, run the command "\
                                  "`kameleon templates`"
        else
          files2copy = tpl.base_recipes_files + tpl.files
          files2copy.each do |path|
            relative_path = path.relative_path_from(Kameleon.env.templates_path)
            dst = File.join(Kameleon.env.workspace, relative_path)
            copy_file(path, dst)
          end
        end
      end
    end

    class Repository < Thor

      desc "add [NAME] [URL]", "Adds a new named <name> repository at <url>."
      def add(name, url)
      end

      desc "list", "Lists available repositories."
      def list(repository_name, repository_url)
      end

      desc "rename [OLD_NAME] [NEW_NAME]", "Renames the repository named <old> to <new>"
      def rename(old_name, new_name)
      end

      desc "update [NAME]", "Updates a named <name> repository"
      def update(old_name, new_name)
      end
      default_task :list
    end
  end

  class Main < Thor
    include Thor::Actions

    register CLI::Recipe, 'recipe', 'recipe', 'Manages the local recipes'
    register CLI::Template, 'template', 'template', 'Lists and imports templates'
    register CLI::Repository, 'repository', 'repository', 'Manages set of remote git repositories'

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
    method_option :checkpoint, :type => :boolean ,
                  :default => false,
                  :desc => "Enables checkpoint"
    method_option :cache, :type => :boolean,
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

    def self.source_root
      Kameleon.source_root
    end

  end

end
