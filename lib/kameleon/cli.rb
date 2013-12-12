require 'kameleon/engine'


module Kameleon
  class CLI < Thor
    class_option :debug,:type => :boolean , :default => false, :desc => "enable debugging"

    class_option :worspace, :aliases => '-w', :type => :string,
                 :default => FileUtils.pwd,
                 :desc => 'Change the kameleon workspace directory. ' \
                          '(The folder containing your recipes folder).'

    method_option :template, :aliases => "-t", :desc => "Starting from a template", :default => "new_recipe"
    method_option :force,:type => :boolean , :default => false, :aliases => "-f", :desc => "overwrite the recipe"
    desc "new", "Create a new recipe"
    def new(recipe_name)
      @env.ui.success "Neeeew"
    end

    desc "list", "Lists all defined recipes"
    def list
      puts "list"
    end

    desc "build [RECIPE_NAME]", "Build box from the recipe"
    method_option :force, :type => :boolean , :default => false, :aliases => "-f", :desc => "force the build"
    def build(recipe_name)
      puts "recipes"
    end

    def initialize(args=[], options={}, config={})
      super
      @env = config[:env]
    end

  end
end
