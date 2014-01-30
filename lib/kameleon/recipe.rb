# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/macrostep'
require 'pry'

module Kameleon
  class Recipe
    attr_accessor :path, :name, :global, :sections, :aliases, :aliases_path, \
                  :checkpoint, :checkpoint_path

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
      @logger = Log4r::Logger.new("kameleon::[recipe]")
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @sections = Section.new
      @required_global = %w(distrib out_context in_context)
      kameleon_id = SecureRandom.uuid
      @system_global = {
        "kameleon_recipe_name" => @name,
        "kameleon_recipe_dir" => File.dirname(@path),
        "kameleon_uuid" => kameleon_id,
        "kameleon_short_uuid" => kameleon_id.split("-").last,
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
      }
      @global = {}
      @logger.debug("Initialize new recipe (#{path})")
      @aliases = {}
      @aliases_path = nil
      @checkpoint = {}
      @checkpoint_path = nil
      load!
      # TODO: Prints fancy dump
      # @logger.debug("Instance variables")
      # instance_variables.each do |v|
      #   @logger.debug("  #{v} = #{instance_variable_get(v)}")
      # end
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
      @global.merge!(yaml_recipe.fetch("global"))
      @global.merge!@system_global
      # Resolve dynamically-defined variables !!
      @global.merge! YAML.load(Utils.resolve_vars(@global.to_yaml, @path, @global))
      # Loads aliases
      load_aliases(yaml_recipe)
      # Loads checkpoint configuration
      load_checkpoint_config(yaml_recipe)

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
        step_path = File.join(steps_dir, section_name, search_dir, name + '.yaml')
        if File.file?(step_path)
          @logger.info("Loading step #{step_path}")
          return Macrostep.new(step_path, args, self)
        end
        @logger.debug("Step #{name} not found in this path: #{step_path}")
      end
      fail RecipeError, "Step #{name} not found"
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

    def load_aliases(yaml_recipe)
      if yaml_recipe.keys.include? "aliases"
        aliases = yaml_recipe.fetch("aliases")
        if aliases.kind_of? Hash
          @aliases = aliases
        elsif aliases.kind_of? String
          path = Pathname.new(File.join(File.dirname(@path), "aliases", aliases))
          if File.file?(path)
            @logger.info("Loading aliases #{path}")
            @aliases = YAML.load_file(path)
            @aliases_path = path
          else
            fail RecipeError, "Aliases file '#{path}' does not exists"
          end
        end
        ## save raw YAML, because YAML.load/YAML.dump strip escaping !
        aliases_file = File.open(@aliases_path, "r")
        raw_yaml_content = aliases_file.read
        aliases_file.close
        list_aliases = @aliases.map {|k, _| k}
        list_aliases.each_with_index  do |k, index|
            start_content = raw_yaml_content.index("#{k}:\n") + k.length + 2
            if index == list_aliases.count - 1
              end_content = raw_yaml_content.length
            else
              next_k = list_aliases[index + 1]
              end_content = raw_yaml_content.index("#{next_k}:\n") - 1
            end
            @aliases[k] = raw_yaml_content[start_content..end_content]
        end
        return @aliases
      end
    end


    def load_checkpoint_config(yaml_recipe)
      if yaml_recipe.keys.include? "checkpoint"
        checkpoint = yaml_recipe.fetch("checkpoint")
        if checkpoint.kind_of? Hash
          @checkpoint = checkpoint
        elsif checkpoint.kind_of? String
          path = Pathname.new(File.join(File.dirname(@path), "checkpoints", checkpoint))
          if File.file?(path)
            @logger.info("Loading checkpoint configuration #{path}")
            @checkpoint = YAML.load_file(path)
            @checkpoint_path = path
          else
            fail RecipeError, "Checkpoint configuraiton file '#{path}' does not exists"
          end
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
  class RecipeTemplate < Recipe

    def copy_template(dest_path, recipe_name, force)
      Dir::mktmpdir do |tmp_dir|
        recipe_path = File.join(tmp_dir, recipe_name + '.yaml')
        FileUtils.cp(@path, recipe_path)
        File.open(recipe_path, 'w+') do |file|
          tpl = ERB.new(@recipe_content)
          result = tpl.result(binding)
          file.write(result)
        end

        @files.each do |path|
          relative_path = path.relative_path_from(Kameleon.env.templates_path)
          dst = File.join(tmp_dir, File.dirname(relative_path))
          FileUtils.mkdir_p dst
          FileUtils.cp(path, dst)
          @logger.debug("Copying '#{path}' to '#{dst}'")
        end
        # Create recipe dir if not exists
        FileUtils.mkdir_p Kameleon.env.recipes_path
        FileUtils.cp_r(Dir[tmp_dir + '/*'], Kameleon.env.recipes_path)
      end
    end
  end
end
