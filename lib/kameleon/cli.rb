require 'kameleon/engine'
require 'kameleon/recipe'


module Kameleon
  class CLI < Thor

    class_option :debug,:type => :boolean , :default => false, :desc => "enable debugging"
    class_option :no_color,:type => :boolean , :default => false, :desc => "disable output color"

    class_option :workspace, :aliases => '-w', :type => :string,
                 :default => FileUtils.pwd,
                 :desc => 'Change the kameleon workspace directory. ' \
                          '(The folder containing your recipes folder).'


    method_option :template, :aliases => "-t", :desc => "Starting from a template", :default => "empty_recipe"
    method_option :force,:type => :boolean , :default => false, :aliases => "-f", :desc => "overwrite the recipe"
    desc "new [RECIPE_NAME]", "Create a new recipe"
    def new(recipe_name)
      @env.logger.debug('cli::new') {"Enter CLI::new method"}
      template_path = File.join(@env.templates_dir, options[:template]) + '.yaml'
      template_recipe = Recipe.new(@env, template_path)
      recipe_dir = File.join(options[:workspace], 'recipes' )

      # TODO add a warning and add a number to the copied file if already
      # exists in the workdir
      @env.logger.debug('cli::new') {"Cloning template in:\n #{template_path}\n to:\n #{recipe_dir} "}
      @env.ui.info "Cloning from templates #{options[:template]}"
      Dir::mktmpdir do |tmp_dir|
        FileUtils.cp(template_path, File.join(tmp_dir, recipe_name + '.yaml'))
        template_recipe.sections.each do |key, macrosteps|
          macrosteps.each do |macrostep|
            relative_path = Pathname.new(macrostep.path).relative_path_from(Pathname.new(@env.templates_dir))
            dst = File.join(tmp_dir, File.dirname(relative_path))
            FileUtils.mkdir_p dst
            FileUtils.cp(macrostep.path, dst)
          end
        end
        # Create recipe dir if not exists
        FileUtils.mkdir_p recipe_dir
        FileUtils.cp_r(Dir[tmp_dir + '/*'], recipe_dir)
      end
      @env.ui.success "New recipe \"#{recipe_name}\" as been created in #{recipe_dir}"
    end

    desc "list", "Lists all defined templates"
    def list
    end

    desc "version", "Prints the Kameleon's version information"
    def version
      Kameleon.ui.info "Kameleon version #{Kameleon::VERSION}"
    end
    map %w(-v --version) => :version

    desc "build [RECIPE_NAME]", "Build box from the recipe"
    method_option :force, :type => :boolean , :default => false, :aliases => "-f", :desc => "force the build"
    def build(recipe_name)
      engine = Kameleon::Engine.new(@env, recipe_name)
      engine.build
    end

    def initialize(args=[], options={}, config={})
      super
      @env = config[:env]
    end

  end
end
