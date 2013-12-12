# Manage kameleon recipes
require 'kameleon/utils'

module Kameleon
  class Recipe
    # define section constant
    class Section
      BOOTSTRAP="bootstrap"
      SETUP="setup"
      EXPORT="export"
      def self.sections()
        [ 
          BOOTSTRAP, 
          SETUP,
          EXPORT,
        ]
      end
    end
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

    def load!(path)
      # Find recipe path
      @path = path
      fail Kameleon::Error, "Could not find this following recipe : #{@path}" \
           unless File.file? @path
      @env.logger.info('recipe') { 'Loading ' + @path }

      yaml_recipe = YAML.load_file @path
      fail "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail Kameleon::Error, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      #Load Global variables
      @global.merge(yaml_recipe.fetch("global"))

      @global.each do |key, value|
        fail "Recipe misses required variable: #{key}" if value.nil?
      end
      
      #Find and load steps
      Section.sections.each |section| do
        yaml_recipe.fetch(section).each do |macrostep|
          
          #check if it's a string or a dict
          if macrostep.kind_of?(String)
            step = macrostep
          elsif macrostep.kind_of?(Dict)
            step = macrostep.keys[0]
            #Load options
            options = macrostep.value[0]
          else
            fail "Malformed yaml recipe in section: "+ section
          end

          # find the path of the macrostep
          step_path = find_macrostep(step_name, section)

          # save the macrostep in the section
          @sections[section].push(Macrostep.new(step_path, options))
        end
      end
    end


    # check for macrostep file (distro-specific or default)
    # :returns: workdir relative path of the step
    def find_macrostep(step_name, section)
      workdir = File.basename @path
        [@global['distrib'], 'default', ''] do |to_search_dir|
          if File.file?(step_path = workdir +'/'+ section +'/'+ to_search_dir + '/' + step_name)
            @env.ui.succes('recipe') { "Step #{step_name} found in this path: "+ step_path }
            return step_path
          end
          @env.ui.debug('recipe') { "Step #{step_name} not found in this path: "+ step_path }
        end
        fail "Step #{step_name} not found"
    end

    # :returns: macrostep
    def resolve_macrostep(raw_macrostep, args)
    end


  end
end
