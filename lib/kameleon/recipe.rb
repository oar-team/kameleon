# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/step'

module Kameleon

  class Recipe
    attr_accessor :path, :name, :global, :sections, :aliases, :aliases_path, \
                  :checkpoint, :checkpoint_path, :metainfo

    def initialize(path)
      @logger = Log4r::Logger.new("kameleon::[recipe]")
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @recipe_content = File.open(@path, 'r') { |f| f.read }
      @sections = {
        "bootstrap" => Section.new("bootstrap"),
        "setup" => Section.new("setup"),
        "export" => Section.new("export"),
      }
      @required_global = %w(out_context in_context)
      kameleon_id = SecureRandom.uuid
      @global = {
        "kameleon_recipe_name" => @name,
        "kameleon_recipe_dir" => File.dirname(@path),
        "kameleon_uuid" => kameleon_id,
        "kameleon_short_uuid" => kameleon_id.split("-").last,
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
      }
      @aliases = {}
      @checkpoint = nil
      @files = []
      @logger.debug("Initialize new recipe (#{path})")
      load!
    end

    def load!
      # Find recipe path
      @logger.notice("Loading #{@path}")
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load File.open @path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error"
      end
      unless yaml_recipe.key? "global"
        fail RecipeError, "Recipe misses 'global' section"
      end

      #Load Global variables
      @global.merge!(yaml_recipe.fetch("global"))
      # Resolve dynamically-defined variables !!
      resolved_global = Utils.resolve_vars(@global.to_yaml, @path, @global)
      @global.merge! YAML.load(resolved_global)

      # Loads aliases
      load_aliases(yaml_recipe)
      # Loads checkpoint configuration
      load_checkpoint_config(yaml_recipe)

      #Find and load steps
      steps_dir = File.join(File.dirname(@path), 'steps')
      @global['include_steps'] ||= []
      @global['include_steps'] = [global['include_steps']].push ''
      @global['include_steps'].flatten!
      @global['include_steps'].compact!
      @sections.values.each do |section|
        dir_to_search = @global['include_steps'].map do |path|
          [File.join(steps_dir, section.name, path),
            File.join(steps_dir, path)]
        end
        dir_to_search.flatten!
        if yaml_recipe.key? section.name
          yaml_section = yaml_recipe.fetch(section.name)
          next unless yaml_section.kind_of? Array
          yaml_section.each do |raw_macrostep|

            # Get macrostep name and arguments if available
            if raw_macrostep.kind_of? String
              name = raw_macrostep
              args = nil
            elsif raw_macrostep.kind_of? Hash
              name = raw_macrostep.keys[0]
              args = raw_macrostep.values[0]
            else
              fail RecipeError, "Malformed yaml recipe in section: "\
                                "#{section.name}"
            end

            # Load macrostep yaml
            loaded = false
            dir_to_search.each do |dir|
              macrostep_path = Pathname.new(File.join(dir, name + '.yaml'))
              if File.file?(macrostep_path)
                @logger.notice("Loading macrostep #{macrostep_path}")
                macrostep = load_macrostep(macrostep_path, name, args)
                section.macrosteps.push(macrostep)
                @files.push(macrostep_path)
                @logger.debug("Macrostep '#{name}' found in this path: " \
                              "#{macrostep_path}")
                loaded = true
                break
              else
                @logger.debug("Macrostep '#{name}' not found in this path: " \
                              "#{macrostep_path}")
              end
            end
            fail RecipeError, "Step #{name} not found" unless loaded
          end
        end
      end
      @logger.notice("Loading recipe metadata")
      @metainfo = {
        "description" => Utils.extract_meta_var("description", @recipe_content),
        "recipe" => Utils.extract_meta_var("recipe", @recipe_content),
        "template" => Utils.extract_meta_var("template", @recipe_content),
      }
    end

    def load_aliases(yaml_recipe)
      if yaml_recipe.keys.include? "aliases"
        aliases = yaml_recipe.fetch("aliases")
        if aliases.kind_of? Hash
          @aliases = aliases
        elsif aliases.kind_of? String
          path = Pathname.new(File.join(File.dirname(@path), "aliases", aliases))
          if File.file?(path)
            @logger.notice("Loading aliases #{path}")
            @aliases = YAML.load_file(path)
            @files.push(path)

            ## save raw YAML, because YAML.load/YAML.dump strip escaping !
            aliases_file = File.open(path, "r")
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
          else
            fail RecipeError, "Aliases file '#{path}' does not exists"
          end
        end
      end
    end

    def load_checkpoint_config(yaml_recipe)
      if yaml_recipe.keys.include? "checkpoint"
        checkpoint = yaml_recipe.fetch("checkpoint")
        if checkpoint.kind_of? Hash
          @checkpoint = checkpoint
          @checkpoint["path"] = @path
        elsif checkpoint.kind_of? String
          path = Pathname.new(File.join(File.dirname(@path),
                              "checkpoints",
                              checkpoint))
          if File.file?(path)
            @logger.notice("Loading checkpoint configuration #{path}")
            @checkpoint = YAML.load_file(path)
            @checkpoint["path"] = path.to_s
            @files.push(path)
          else
            fail RecipeError, "Checkpoint configuraiton file '#{path}' " \
                              "does not exists"
          end
        end
      end
    end

    def load_macrostep(step_path, name, args)
      macrostep_yaml = YAML.load_file(step_path)
      local_variables = {}
      loaded_microsteps = []
      # Basic macrostep syntax check
      if not macrostep_yaml.kind_of? Array
        fail RecipeError, "The macrostep #{step_path} is not valid "
                           "(should be a list of microsteps)"
      end
      # Load default local variables
      macrostep_yaml.each do |yaml_microstep|
        key = yaml_microstep.keys[0]
        value = yaml_microstep[key]
        # Set new variable if not defined yet
        if value.kind_of? String
          local_variables[key] = @global.fetch(key, value)
        else
          loaded_microsteps.push Microstep.new(yaml_microstep)
        end
      end
      selected_microsteps = []
      if args
        args.each do |entry|
          if entry.kind_of? Hash
            # resolve variable before using it
            entry.each do |key, value|
              local_variables[key] = value
            end
          elsif entry.kind_of? String
            selected_microsteps.push entry
          end
        end
      end
      unless selected_microsteps.empty?
        # Some steps are selected so remove the others
        # WARN: Allow the user to define this list not in the original order
        strip_microsteps = []
        selected_microsteps.each do |microstep_name|
          macrostep = find_microstep(microstep_name, loaded_microsteps)
          if macrostep.nil?
            fail RecipeError, "Can't find microstep '#{microstep_name}' "\
                              "in macrostep file '#{step_path}'"
          else
            strip_microsteps.push(macrostep)
          end
        end
        loaded_microsteps = strip_microsteps
      end
      return Macrostep.new(name, loaded_microsteps, local_variables, step_path)
    end

    def find_microstep(microstep_name, loaded_microsteps)
      @logger.debug("Looking for microstep #{microstep_name}")
      loaded_microsteps.each do |microstep|
        if microstep_name.eql? microstep.name
          return microstep
        end
      end
    end

    def resolve!
      consistency_check
      resolve_checkpoint unless @checkpoint.nil?

      @logger.notice("Resolving variables")
      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          macrostep.resolve_variables!(@global)
        end
      end

      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          # First pass : resolve aliases
          @logger.debug("Resolving aliases for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each do |microstep|
            microstep.commands.map! do |cmd|
              # resolve alias
              @aliases.keys.include?(cmd.key) ? resolve_alias(cmd) : cmd
            end
          end
          # flatten for multiple-command alias + variables
          @logger.debug("Resolving check statements for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each { |microstep| microstep.commands.flatten! }
          # Second pass : resolve variables + clean/init hooks
          macrostep.microsteps.each do |microstep|
            microstep.commands.map! do |cmd|
              resolve_hooks(cmd, macrostep)
            end
          end
          # remove nil values
          @logger.debug("Compacting macrostep '#{macrostep.name}'")
          macrostep.microsteps.each { |microstep| microstep.commands.compact! }
        end
      end
      calculate_step_identifiers
    end

    def consistency_check()
      # flatten list of hash to an a hash
      %w(out_context in_context).each do |context_name|
        if @global[context_name].kind_of? Array
          old_context_args = @global[context_name].clone
          @global[context_name] = {}
          old_context_args.each do |arg|
            @global[context_name].merge!(arg)
          end
        end
      end
      @logger.notice("Starting recipe consistency check")
      missings = []
      @required_global.each do |key|
        missings.push key unless @global.key? key
      end
      fail RecipeError, "Required parameters missing in global section :" \
                        " #{missings.join ' '}" unless missings.empty?
      # check context args
      required_args = %w(cmd)
      missings = []
      %w(out_context in_context).each do |context_name|
        context = @global[context_name]
        missings = required_args - (context.keys() & required_args)
        fail RecipeError, "Required paramater missing for #{context_name}:" \
                          " #{ missings.join ' ' }" unless missings.empty?
      end
      unless @checkpoint.nil?
        required_args = %w(create apply remove list)
        missings = []
        missings = required_args - (@checkpoint.keys() & required_args)
        fail RecipeError, "Required paramater missing for checkpoint:" \
                          " #{ missings.join ' ' }" unless missings.empty?
      end
    end

    def resolve_checkpoint()
      %w(create apply remove list).each do |key|
        @checkpoint[key] = Utils.resolve_vars(@checkpoint[key],
                                              @checkpoint["path"],
                                              @global)
      end
    end

    def resolve_alias(cmd)
      name = cmd.key
      command_pattern = @aliases.fetch(name).clone
      args = YAML.load(cmd.string_cmd)[name]
      args = [].push(args).flatten  # convert args to array
      expected_args_number = command_pattern.scan(/@\d+/).uniq.count
      if expected_args_number != args.count
        if args.length == 0
          msg = "#{name} takes no arguments (#{args.count} given)"
        else
          msg = "#{name} takes exactly #{expected_args_number} arguments"
                " (#{args.count} given)"
        end
        raise RecipeError, msg
      end
      args.each_with_index do |arg, i|
        command_pattern.gsub!("@#{i+1}", arg.inspect)
      end
      YAML.load(command_pattern).map { |cmd_hash| Command.new(cmd_hash) }
    end

    #handle clean methods
    def resolve_hooks(cmd, macrostep)
      if (cmd.key =~ /on_(.*)clean/ || cmd.key =~ /on_(.*)init/)
        cmds = []
        if cmd.value.kind_of?(Array)
          cmds = cmd.value.map do |c|
            @aliases.keys.include?(c.key) ? resolve_alias(c) : c
          end
          cmds = cmds.flatten
        else
          fail RecipeError, "Invalid #{cmd.key} arguments"
        end
        if cmd.key.eql? "on_clean"
          microstep_name = "_clean_#{macrostep.name}_" \
                           "#{macrostep.clean_microsteps.count}"
          new_clean_microstep = Microstep.new({microstep_name => []})
          new_clean_microstep.on_checkpoint = "redo"
          new_clean_microstep.commands = cmds.clone
          macrostep.clean_microsteps.unshift new_clean_microstep
          return
        elsif cmd.key.eql? "on_init"
          microstep_name = "_init_#{macrostep.name}_" \
                           "#{macrostep.init_microsteps.count}"
          new_init_microstep = Microstep.new({microstep_name=> []})
          new_init_microstep.on_checkpoint = "redo"
          new_init_microstep.commands = cmds.clone
          macrostep.init_microsteps.unshift new_init_microstep
          return
        else
          @sections.values.each do |section|
            section.clean_macrostep
            if cmd.key.eql? "on_#{section.name}_clean"
              microstep_name = "_clean_#{section.name}_"\
                               "#{section.clean_macrostep.microsteps.count}"
              new_clean_microstep = Microstep.new({microstep_name=> []})
              new_clean_microstep.commands = cmds.clone
              new_clean_microstep.on_checkpoint = "redo"
              section.clean_macrostep.microsteps.unshift new_clean_microstep
              return
            elsif cmd.key.eql? "on_#{section.name}_init"
              microstep_name = "_init_#{section.name}_"\
                               "#{section.init_macrostep.microsteps.count}"
              new_init_microstep = Microstep.new({microstep_name=> []})
              new_init_microstep.commands = cmds.clone
              new_init_microstep.on_checkpoint = "redo"
              section.init_macrostep.microsteps.push new_init_microstep
              return
            end
          end
        end
        fail RecipeError, "Invalid command : '#{cmd.key}'"
      else
        return cmd
      end
    end

    def microsteps
      if @microsteps.nil?
        microsteps = []
        @sections.values.each do |section|
          section.sequence do |macrostep|
            macrostep.sequence do |microstep|
              microsteps.push microstep
            end
          end
        end
        @microsteps = microsteps
      end
      return @microsteps
    end

    def calculate_step_identifiers
      @logger.notice("Calculating microstep identifiers")
      base_salt = ""
      order = 0
      @sections.values.each do |section|
        section.sequence do |macrostep|
          macrostep.sequence do |microstep|
            base_salt = microstep.calculate_identifier base_salt
            slug = "#{section.name}/#{macrostep.name}/#{microstep.name}"
            microstep.slug = slug
            microstep.order = (order += 1)
            @logger.debug("  #{microstep.slug}: #{microstep.identifier}")
          end
        end
      end
    end

    def to_hash
      recipe_hash = {
        "name" => @name,
        "path" => @path.to_s,
        "files" => @files.map {|p| p.to_s },
        "global" => @global,
        "required_global" => @required_global,
      }
      unless @aliases.nil?
        aliases = {}
        @aliases.each { |k, v| aliases[k] = YAML.load(v) }
        recipe_hash["aliases"] = aliases
      end
      recipe_hash["checkpoint"] = @checkpoint unless @checkpoint.nil?
      recipe_hash["steps"] = to_array
      return recipe_hash
    end

    def to_array
      array = []
      @sections.values.each do |section|
        section.to_array.each { |m|  array.push m }
      end
      return array
    end

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
