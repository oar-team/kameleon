# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/macrostep'

module Kameleon
  class Recipe
    attr_accessor :path, :name, :global, :sections

    # define section constant
    class Section < Utils::OrderedHash
      attr_accessor :clean

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

      def initialize()
        @clean = {}
        Section::sections.each{ |section| @clean[section] = Macrostep::Microstep.new({"clean_#{@section}"=> []}) }
        super
      end
    end

    def initialize(path)
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @sections = Section.new
      @global = { "distrib" => nil,
                  "requirements" => "",
                  "workdir" => File.join(Kameleon.env.build_dir, @name),
                  "launch_context" => nil,
                  "build_context" => nil }
      load!
    end

    def load!
      # Find recipe path
      Kameleon.ui.confirm "Loading #{@path}"
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load File.open @path
      fail RecipeError, "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail RecipeError, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      #Load Global variables
      @global.merge!(yaml_recipe.fetch("global"))
      # Make an object list from a string comma (or space) separated list
      @global["requirements"] = @global["requirements"].split(%r{,\s*})\
                                                       .map(&:split).flatten

      #Find and load steps
      Section.sections.each do |section_name|
        if yaml_recipe.key? section_name
          @sections[section_name] = []
          yaml_recipe.fetch(section_name).each do |macrostep_yaml|
            macrostep_instance = load_macrostep(macrostep_yaml, section_name)
            # save the macrostep in the section
            @sections[section_name].push(macrostep_instance)
          end
        end
      end
      # Resolve dynamically-defined variables !!
      @global.merge! YAML.load(Utils.resolve_vars(YAML.dump(@global), @path, @global))
    end

    def load_macrostep(raw_macrostep, section_name)
      #check if it's a string or a dict
      if raw_macrostep.kind_of? String
        name = raw_macrostep
      elsif raw_macrostep.kind_of? Hash
        name = raw_macrostep.keys[0]
        args = raw_macrostep.values[0]
      else
        fail RecipeError, "Malformed yaml recipe in section: "+ section_name
      end
      # find the path of the macrostep
      steps_dir = File.join(File.dirname(@path), 'steps')
      [@global['distrib'], 'default', ''].each do |search_dir|
        path = File.join(steps_dir, section_name, search_dir, name + '.yaml')
        if File.file?(path)
          Kameleon.ui.confirm "Loading #{path}"
          return Macrostep.new(path, args, self)
        end
        Kameleon.ui.debug "Step #{name} not found in this path: #{path}"
      end
      fail RecipeError, "Step #{name} not found" unless File.file?(path)
    end

    def resolve!
      @sections.each{ |key, macrosteps| macrosteps.each{|m| m.resolve!} }
    end

    def check_recipe
      missings = []
      @global.each { |key, value| missings.push(key) if value.nil? }
      fail RecipeError, "Required parameters missing in global section :" \
                        " #{missings.join ' '}" unless missings.empty?
    end
  end
end
