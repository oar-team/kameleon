# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/macrostep'
require 'pry'

module Kameleon
  class Recipe
    attr_accessor :path, :name, :global, :sections

    # define section constant
    class Section < Utils::OrderedHash
      attr_accessor :clean, :init

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
        @init = {}
        Section::sections.each do |name|
          @clean[name] = Macrostep::Microstep.new({"clean_#{name}"=> []})
          @init[name] = Macrostep::Microstep.new({"init_#{name}"=> []})
        end
        super
      end
    end

    def initialize(path)
      @logger = Log4r::Logger.new("kameleon::recipe")
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @sections = Section.new
      @required_global = %w(distrib out_context in_context)
      @default_global = { "requirements" => "" }
      kameleon_id = SecureRandom.uuid
      @system_global = {
        "kameleon_uuid" => kameleon_id,
        "kameleon_short_uuid" => kameleon_id.split("-").last,
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
      }
      @global = {}
      @logger.debug("Initialize new recipe (#{path})")
      @logger.debug("Instance variable before load")
      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end
      load!
    end

    def load!
      # Find recipe path
      @logger.info("Loading #{@path}")
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load File.open @path
      fail RecipeError, "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail RecipeError, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      #Load Global variables
      @global.merge!@default_global.merge(yaml_recipe.fetch("global"))
      # Make an object list from a string comma (or space) separated list
      @global["requirements"] = @global["requirements"].split(%r{,\s*})\
                                                       .map(&:split).flatten
      @global.merge!@system_global
      #Find and load steps
      Section.sections.each do |section_name|
        @sections[section_name] = []
        if yaml_recipe.key? section_name
          yaml_recipe.fetch(section_name).each do |macrostep_yaml|
            macrostep_instance = load_macrostep(macrostep_yaml, section_name)
            # save the macrostep in the section
            @sections[section_name].push(macrostep_instance)
          end
        end
      end
      # Resolve dynamically-defined variables !!
      @global.merge! YAML.load(Utils.resolve_vars(YAML.dump(@global), @path, @global))
      @logger.debug("Instance variable after load")
      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end
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
          @logger.info("Loading #{path}")
          return Macrostep.new(path, args, self)
        end
        @logger.debug("Step #{name} not found in this path: #{path}")
      end
      fail RecipeError, "Step #{name} not found" unless File.file?(path)
    end

    def resolve!
      @logger.info("Starting recipe variables resolution")
      @sections.each{ |key, macrosteps| macrosteps.each{|m| m.resolve!} }
      # global args more flat
      %w(out_context in_context).each do |context_name|
        old_context_args = @global[context_name].clone
        @global[context_name] = {}
        old_context_args.each do |arg|
          @global[context_name].merge!(arg)
        end
      end
    end

    def check
      @logger.info("Starting recipe consistency check")
      missings = []
      @required_global.each { |key| missings.push cmd unless @global.key? key }
      fail RecipeError, "Required parameters missing in global section :" \
                        " #{missings.join ' '}" unless missings.empty?
      # check context args
      required_args = %w(cmd workdir)
      %w(out_context in_context).each do |context_name|
        context = @global[context_name]
        fail RecipeError, "Required arguments missing for #{context_name}:"\
                        " #{ required_args.inspect }" unless context.kind_of? Array
        args = context.map { |i| i.keys }.flatten
        required_args.each do |arg|
          @global[context] unless args.include?(arg)
          fail RecipeError, "Required argument missing for #{context_name}:"\
                          " #{ arg }" unless args.include?(arg)
        end
      end
    end
  end
end
