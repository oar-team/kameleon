# Manage kameleon recipes
require 'kameleon/utils'
require 'pp'

module Kameleon
  class Recipe
    attr_accessor :global, :sections, :check_cmds
    def initialize(env, recipe_query)
      @env = env
      @global = {}
      @check_cmds = []
      @sections = {}
      load(find(recipe_query, include_paths))
    end

    # query could be recipe name or path
    # :returns: path
    def find(recipe_query, include_paths)
      searched_pathes = ""
      # Preserve paths order
      if File.basename(recipe_query).eql? recipe_query
        # recipe_query is not a path
        pathes_to_search = []
        include_paths.each do |p|
          pathes_to_search.push(p)
          pathes_to_search.push(File.join(p, "recipes"))
        end
        pathes_to_search.each do |dir|
          if File.file?(path1 = File.join(dir, recipe_query + ".yaml"))
            return path1
          elsif File.file?(path2 = File.join(dir, recipe_query))
            return path2
          else
            searched_pathes = searched_pathes + "\n * " + path2 + "[.yaml]"
          end
        end
      elsif File.exist?(recipe_query)
          return recipe_query
      end
      fail "could not find recipe in none of the following files " +
           ":#{searched_pathes}"
    end

    # :returns: path
    def load(recipe_path)
      required_globals = { "distrib" => nil,
                           "rootfs" => "$$workdir_base/chroot",
                           "exec_cmd" => "chroot $$rootfs" }
      @env.logger.info('Loading ' + recipe_path)
      yaml_recipe = YAML.load(File.open(recipe_path))
      if yaml_recipe.kind_of?(Hash)
        fail "Recipe misses 'global' section" unless yaml_recipe.key?("global")
        @global = yaml_recipe.fetch("global")
        required_globals.each do |key, value|
          fail "Recipe misses required variable: #{key}" unless @global.key?(key) || !value.nil?
          @global[key] = value if @global.fetch(key, nil).nil?
        end
        puts @global
      end
    end


    # :returns: list
    def load_macrostep(path)
    end

    # check for macrostep file (distro-specific or default)
    # :returns: path
    def find_macrostep(step_name)
    end

    # :returns: macrostep
    def resolve_macrostep(raw_macrostep, args)
    end


  end
end
