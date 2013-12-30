require 'kameleon/engine'
require 'kameleon/recipe'
require 'kameleon/utils'

module Kameleon
  class CLI < Thor

    class_option :no_color, :type => :boolean, :default => false,
                 :desc => "Disable colorization in output"
    class_option :verbose, :type => :boolean, :default => false,
                 :desc => "Enable verbose output mode", :aliases => "-V"
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
      Kameleon.ui.debug "Enter CLI::new method"
      templates_path = Kameleon.env.templates_path
      recipes_path = Kameleon.env.recipes_path
      template_path = File.join(templates_path, options[:template]) + '.yaml'
      template_recipe = Recipe.new(template_path)

      # TODO add a warning and add a number to the copied file if already
      # exists in the workdir
      Kameleon.ui.confirm "Cloning template '#{options[:template]}'"
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
      Kameleon.ui.confirm "New recipe \"#{recipe_name}\" as been created in #{recipes_path}"
    end

    desc "list", "Lists all defined templates"
    def list
      # TODO: Lists all defined templates
    end
    map "-L" => :list

    desc "version", "Prints the Kameleon's version information"
    def version
      Kameleon.ui.confirm "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version

    desc "build [RECIPE_NAME]", "Build box from the recipe"
    method_option :force, :type => :boolean ,
                  :default => false, :aliases => "-f",
                  :desc => "force the build"
    def build(recipe_name)
      recipe_path = File.join(Kameleon.env.recipes_path, recipe_name) + '.yaml'
      Kameleon::Engine.new(Recipe.new(recipe_path)).build
    end

    # Hack Thor to init Kameleon env soon
    def self.init(base_config)
      options = base_config[:shell].base.options
      # Attach the UI
      Kameleon.ui = ::Kameleon::UI::Shell.new(options)
      Kameleon.ui.level = options["verbose"] ? "debug" : "info"
      Kameleon.env = Kameleon::Environment.new(options)
    end

    def self.start(given_args=ARGV, config={})
        config[:shell] ||= Thor::Base.shell.new
        dispatch(nil, given_args.dup, nil, config) { init(config) }
    end
  end
end
