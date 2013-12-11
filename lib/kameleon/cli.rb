require 'kameleon/engine'


module Kameleon
  class CLI < Thor
    class_option :debug,:type => :boolean , :default => false, :desc => "enable debugging"

    class_option :workdir, :aliases => '-w', :type => :string,
                 :default => FileUtils.pwd,
                 :desc => 'Change the working directory. ' \
                          '(The folder containing your recipes folder).'

    method_option :template, :aliases => "-t", :desc => "Starting from a template", :default => "new_recipe"
    method_option :force,:type => :boolean , :default => false, :aliases => "-f", :desc => "overwrite the recipe"
    desc "new", "Create a new recipe"
    def new(recipe_name)
      puts "new"
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

  end
end
