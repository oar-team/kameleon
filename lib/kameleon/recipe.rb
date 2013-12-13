# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/macrostep'

module Kameleon
  class Recipe
    attr_accessor :sections

    # define section constant
    class Section < OrderedHash
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
    def initialize(env, path)
      @env = env
      @name = File.basename( path, ".yaml" ) 
      @path = path
      @check_cmds = []
      @sections = Section.new
      @global = { "distrib" => nil,
                  "workdir" => File.join(@env.build_dir, @name),
                  "rootfs" => "$$workdir/chroot",
                  "exec_cmd" => "fakechroot $$rootfs" }
      load!
    end

    def load!
      # Find recipe path
      fail Kameleon::Error, "Could not find this following recipe : #{@path}" \
           unless File.file? @path
      @env.logger.info('recipe') { 'Loading ' + @path }
      yaml_recipe = YAML.load File.open @path

      fail Error, "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail Error, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      #Load Global variables
      @global.merge!(yaml_recipe.fetch("global"))

      @global.each do |key, value|
        fail "Recipe misses required variable: #{key}" if value.nil?
      end
      
      #Find and load steps
      Section.sections.each do |section|
        yaml_recipe.fetch(section).each do |macrostep|
          
          #check if it's a string or a dict
          if macrostep.kind_of? String
            step = macrostep
          elsif macrostep.kind_of? Hash
            step = macrostep.keys[0]
            #Load options
            options = macrostep.values[0]
          else
            fail "Malformed yaml recipe in section: "+ section
          end

          # find the path of the macrostep
          step_path = find_macrostep(step, section)

          # save the macrostep in the section
          @sections[section]= []
          @sections[section].push(Macrostep.new(step_path, options))
        end
      end
    rescue Psych::SyntaxError => e
      @env.logger.debug('recipe') { e.backtrace.join "\n" }
      raise Error, e
    end


    # check for macrostep file (distro-specific or default)
    # :returns: absolute path of the macrostep
    def find_macrostep(step_name, section)
      workdir = File.join(File.dirname(@path), 'steps')
        [@global['distrib'], 'default', ''].each do |to_search_dir|
          if File.file?(step_path = workdir +'/'+ section +'/'+ to_search_dir + '/' + step_name +'.yaml')
            @env.ui.success "Step #{step_name} found in this path: "+ step_path
            return step_path
          end
          @env.logger.info('recipe') { "Step #{step_name} not found in this path: "+ step_path }
        end
        fail "Step #{step_name} not found"
    end
  end
end
