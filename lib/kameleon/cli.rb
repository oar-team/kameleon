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
      path = File.join(@env.templates_dir, recipe_name) + '.yaml'
      Recipe.new(@env, path)

      @env.ui.info "Cloning from templates #{recipe_name}"
      #Dir::mktmpdir do |tmp_dir|
      #  Recipe::Section.sections.each do |section|
      #    recipe[section].each do |step_name| 
      #      step_path = Recipe.find_macrostep(step_name, @env.templates_dir, section)
      #      dst = File.join(tmp_dir, File.dirname(step_path))
      #      FileUtils.mkdir_p(dst)
      #      FileUtils.cp(step_path, dst)
      #    end
      #  end
      #  FileUtils.cp_r(tmp_dir, options[:workspace])
      #end
    rescue => e
      puts e.message
      puts e.backtrace
    end

    desc "list", "Lists all defined templates"
    def list
    end

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
