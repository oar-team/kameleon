# Manage kameleon recipes
require 'kameleon/utils'

module Kameleon
  class Recipe
    attr_accessor :global, :macrosteps
    def initialize(recipe_path)
      @distrib_name = "debian"
      @global = {}
      @macrosteps = []
      # parse recipe here
    end

    # :returns: path
    def load(path)
    end

    # query could be recipe name or path
    # :returns: path
    def find(query)
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
