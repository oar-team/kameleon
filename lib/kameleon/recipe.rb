# Manage kameleon recipes
require 'kameleon/utils'

module Kameleon
  class Recipe
    attr_accessor :global, :sections, :check_cmds
    def initialize(env, name)
      @env = env
      @name = name
      @path = nil
      @check_cmds = []
      @sections = {}
      @global = { "distrib" => nil,
                  "workdir" => File.join(@env.build_dir, @name),
                  "rootfs" => "$$workdir/chroot",
                  "exec_cmd" => "fakechroot $$rootfs" }
      load!
    end

    def load!
      # Find recipe path
      @path = File.join @env.recipes_dir, @name + ".yaml"
      fail Error, "Could not find this following recipe : #{@path}" \
           unless File.file? @path
      @env.logger.info('recipe') { 'Loading ' + @path }
      yaml_recipe = YAML.load File.open @path

      fail Error, "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail Error, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      @global.merge(yaml_recipe.fetch("global"))

      @global.each do |key, value|
        fail "Recipe misses required variable: #{key}" if value.nil?
      end
    rescue Psych::SyntaxError => e
      @env.logger.debug('recipe') { e.backtrace.join "\n" }
      raise Error, e
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
