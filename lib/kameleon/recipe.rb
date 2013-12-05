# Manage kameleon recipes
require 'kameleon/utils'

module Kameleon
  class Recipe
    attr_accessor :global, :sections, :check_cmds
    def initialize(recipe_query, include_paths)
      @distrib_name = "debian"
      @global = {}
      @check_cmds = []
      @sections = {}
      puts find(recipe_query, include_paths)
      # load(find(recipe_query, include_paths))
    end

    # query could be recipe name or path
    # :returns: path
    def find(recipe_query, include_paths)
      current_dir=Dir.pwd
      searched_pathes = ""
      pathes_to_search = []
      pathes_to_search += include_paths
      pathes_to_search += include_paths.map { |p|  p + "/recipes" }
      pathes_to_search += ["#{current_dir}", "#{current_dir}/recipes"]
      path = ""

      pathes_to_search.each do |dir|
        if File.file?(search_path1 = dir + "/" + recipe_query)
          path = search_path1
          break
        elsif File.file?(search_path2 = dir + "/" + recipe_query + ".yaml")
          path = search_path2
          break
        else
          searched_pathes = searched_pathes + "\n * " + search_path1 + "[.yaml]"
        end
      end
      raise ArgumentError, "#{recipe_query}: could not find recipe in none of the following files :#{searched_pathes}" if path == ""


      #  recipe_query, searched_pathes)
      #   exit(2)
      # end
      # begin
      #   puts cyan("->") + green("| Loading " + path)
      #   $recipe = YAML.load(File.open(path))
      # rescue
      #   print "Failed to open recipe file. ", $!, "\n"
      #   exit(2)
      # end
    end

    # :returns: path
    def load(path)

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
