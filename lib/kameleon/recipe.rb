require 'kameleon/utils'
require 'kameleon/step'

module Kameleon

  class Recipe
    attr_accessor :path
    attr_accessor :name
    attr_accessor :global
    attr_accessor :sections
    attr_accessor :aliases
    attr_accessor :aliases_path
    attr_accessor :checkpoint
    attr_accessor :checkpoint_path
    attr_accessor :metainfo
    attr_accessor :files
    attr_accessor :base_recipes_files
    attr_accessor :data

    def initialize(path, kwargs = {})
      @path = Pathname.new(File.expand_path(path))
      @name = (@path.basename ".yaml").to_s
      @recipe_content = File.open(@path, 'r') { |f| f.read }
      @sections = {
        "bootstrap" => Section.new("bootstrap"),
        "setup" => Section.new("setup"),
        "export" => Section.new("export"),
      }
      @cli_global = Kameleon.env.global.clone
      @global = {
        "kameleon_recipe_name" => @name,
        "kameleon_recipe_dir" => File.dirname(@path),
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
        "in_context" => {"cmd" => "/bin/bash", "proxy_cache" => "localhost"},
        "out_context" => {"cmd" => "/bin/bash", "proxy_cache" => "localhost"}
      }
      @aliases = {}
      @checkpoint = nil
      @files = []
      Kameleon.ui.debug("Initialize new recipe (#{path})")
      @base_recipes_files = [@path]
      @data = []
      @steps_dirs = []
      load! :strict => false
    end

    def get_steps_dirs(recipe_path)
      relative_path = recipe_path.to_path.gsub(Kameleon.env.root_dir.to_path + '/', '')
      if relative_path.eql? recipe_path.to_path
        subdirs = [recipe_path.dirname]
      else
        last_dir = Kameleon.env.root_dir
        subdirs = [last_dir]
        relative_path.split("/")[0...-1].each do |p|
          subdir = last_dir.join(p)
          subdirs.push(subdir)
          last_dir = subdir
        end
      end
      steps_dirs = []
      subdirs.reverse_each do |p|
        steps_dirs.push(File.expand_path(File.join(p.to_path, 'steps')))
        steps_dirs.push(File.expand_path(File.join(p.to_path, '.steps')))
      end
      steps_dirs.select! { |x| File.exists? x }
    end

    def load!(kwargs = {})
      # Find recipe path
      Kameleon.ui.debug("Loading #{@path}")
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load_file @path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error : #{@path}"
      end
      # Load entended recipe variables
      yaml_recipe = load_base_recipe(yaml_recipe, @path)
      yaml_recipe.delete("extend")

      # Where we can find steps
      @steps_dirs = @base_recipes_files.map do |recipe_path|
        get_steps_dirs(recipe_path)
      end.flatten!
      @steps_dirs.uniq!

      # Load Global variables
      @global.merge!(yaml_recipe.fetch("global", {}))
      @global.merge!(@cli_global)
      # Resolve dynamically-defined variables !!
      resolved_global = Utils.resolve_vars(@global.to_yaml, @path, @global, self, kwargs)
      resolved_global = @global.merge YAML.load(resolved_global)
      # Loads aliases
      load_aliases(yaml_recipe)
      # Loads checkpoint configuration
      load_checkpoint_config(yaml_recipe)

      resolved_global['include_steps'] ||= []
      resolved_global['include_steps'].push ''
      resolved_global['include_steps'].flatten!
      resolved_global['include_steps'].compact!
      @sections.values.each do |section|
        dir_to_search = @steps_dirs.map do |steps_dir|
          resolved_global['include_steps'].map do |path|
            [File.join(steps_dir, section.name, path),
              File.join(steps_dir, path)]
          end
        end.flatten.select { |x| File.exists? x }

        if yaml_recipe.key? section.name
          yaml_section = yaml_recipe.fetch(section.name)
          next unless yaml_section.kind_of? Array
          yaml_section.each do |raw_macrostep|
            embedded_step = false
            # Get macrostep name and arguments if available
            if raw_macrostep.kind_of? String
              name = Utils.resolve_vars(raw_macrostep, @path, @global, self, kwargs)
              args = nil
            elsif raw_macrostep.kind_of? Hash
              name = Utils.resolve_vars(raw_macrostep.keys[0], @path, @global, self, kwargs)
              args = raw_macrostep.values[0]
            else
              fail RecipeError, "Malformed yaml recipe in section: "\
                                "#{section.name}"
            end
            # Detect if step is embedded
            if not args.nil?
              args.each do |arg|
                if arg.kind_of? Hash
                  if arg[arg.keys[0]].kind_of? Array
                    embedded_step = true
                  end
                end
              end
            end
            if embedded_step
              Kameleon.ui.debug("Loading embedded macrostep #{name}")
              macrostep = load_macrostep(nil, name, args, kwargs)
              section.macrosteps.push(macrostep)
              next
            end
            # Load macrostep yaml
            loaded = false
            dir_to_search.each do |dir|
              macrostep_path = Pathname.new(File.join(dir, name + '.yaml'))
              if File.file?(macrostep_path)
                Kameleon.ui.debug("Loading macrostep #{macrostep_path}")
                macrostep = load_macrostep(macrostep_path, name, args, kwargs)
                section.macrosteps.push(macrostep)
                @files.push(macrostep_path)
                Kameleon.ui.debug("Macrostep '#{name}' found in this path: " \
                                  "#{macrostep_path}")
                loaded = true
                break
              else
                Kameleon.ui.debug("Macrostep '#{name}' not found in this path: " \
                              "#{macrostep_path}")
              end
            end
            fail RecipeError, "Step #{name} not found" unless loaded
          end
        end
      end
      Kameleon.ui.debug("Loading recipe metadata")
      @metainfo = {
        "description" => Utils.extract_meta_var("description", @recipe_content)
      }
    end

    def load_base_recipe(yaml_recipe, path)
      base_recipe_name = yaml_recipe.fetch("extend", "")
      return yaml_recipe if base_recipe_name.empty?

      ## check that the recipe has not already been loaded
      base_recipe_name << ".yaml" unless base_recipe_name.end_with? ".yaml"
      base_recipe_path = File.join(File.dirname(path), base_recipe_name)

      ## check that the recipe has not already been loaded
      return yaml_recipe if @base_recipes_files.include? base_recipe_path

      base_recipe_path << ".yaml" unless base_recipe_path.end_with? ".yaml"
      fail RecipeError, "Could not find this following recipe : #{@recipe_path}" \
         unless File.file? path
      base_yaml_recipe = YAML.load_file base_recipe_path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error : #{base_yaml_recipe}"
      end
      base_yaml_recipe.keys.each do |key|
        if ["export", "bootstrap", "setup"].include? key
          base_yaml_recipe.delete(key) unless yaml_recipe.keys.include? key
        end
      end
      yaml_recipe.keys.each do |key|
        if ["aliases", "checkpoint"].include? key
          base_yaml_recipe[key] = yaml_recipe[key]
        elsif ["export", "bootstrap", "setup"].include? key
          base_section = base_yaml_recipe.fetch(key, [])
          base_section = [] if base_section.nil?
          recipe_section = yaml_recipe[key]
          recipe_section = [] if recipe_section.nil?
          index_base_steps = recipe_section.index("@base")
          unless index_base_steps.nil?
            recipe_section[index_base_steps] = base_section
            recipe_section.flatten!
          end
          base_yaml_recipe[key] = recipe_section
        elsif ["global"].include? key
          base_section = base_yaml_recipe.fetch(key, {})
          base_section = {} if base_section.nil?
          recipe_section = yaml_recipe[key]
          recipe_section = {} if recipe_section.nil?
          base_yaml_recipe[key] = base_section.merge(recipe_section)
        end
      end
      @base_recipes_files.push(Pathname.new(File.expand_path(base_recipe_path)))
      return load_base_recipe(base_yaml_recipe, base_recipe_path)
    end

    def load_aliases(yaml_recipe)
      def load_aliases_file(aliases_file)
        dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "aliases")
        end.flatten
        dir_search.each do |dir_path|
          path = Pathname.new(File.join(dir_path, aliases_file))
          if File.file?(path)
            Kameleon.ui.debug("Loading aliases #{path}")
            @aliases.merge!(YAML.load_file(path))
            @files.push(path)
            return path
          end
        end
        fail RecipeError, "Aliases file for recipe '#{path}' does not exists"
      end
      if yaml_recipe.keys.include? "aliases"
        aliases = yaml_recipe.fetch("aliases")
        if aliases.kind_of? Hash
          @aliases = aliases
        elsif aliases.kind_of? String
          load_aliases_file(aliases)
        elsif aliases.kind_of? Array
          aliases.each do |aliases_file|
            load_aliases_file(aliases_file)
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
          dir_search = @steps_dirs.map do |steps_dir|
              File.join(steps_dir, "checkpoints")
          end.flatten
          dir_search.each do |dir_path|
            path = Pathname.new(File.join(dir_path, checkpoint))
            if File.file?(path)
              Kameleon.ui.debug("Loading checkpoint configuration #{path}")
              @checkpoint = YAML.load_file(path)
              @checkpoint["path"] = path.to_s
              @files.push(path)
              break
            end
          end
          fail RecipeError, "Checkpoint configuraiton file '#{path}' " \
                            "does not exists" if @checkpoint.nil?
        end
        (@checkpoint.keys - ["path"]).each do |key|
          @checkpoint[key].map! do |cmd|
            Kameleon::Command.new(cmd, "checkpoint")
          end
        end
      end
    end

    def load_macrostep(step_path, name, args, kwargs)
      if step_path.nil?
        macrostep_yaml = args
        step_path = @path
      else
        macrostep_yaml = YAML.load_file(step_path)
        # Basic macrostep syntax check
        if not macrostep_yaml.kind_of? Array
          fail RecipeError, "The macrostep #{step_path} is not valid "
                            "(should be a list of microsteps)"
        end
      end
      local_variables = {}
      loaded_microsteps = []
      # Load default local variables
      macrostep_yaml.each do |yaml_microstep|
        key = yaml_microstep.keys[0]
        value = yaml_microstep[key]
        # Set new variable if not defined yet
        if value.kind_of? Array
          loaded_microsteps.push Microstep.new(yaml_microstep)
        else
          local_variables[key] = @global.fetch(key, value)
        end
      end
      unless step_path.nil?
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
      end
      # Resolved neested variables earlier
      local_variables.each do |k, v|
        if v.kind_of? String
          local_variables[k] = Utils.resolve_vars(v, @path, @global, self, kwargs)
        end
      end
      return Macrostep.new(name, loaded_microsteps, local_variables, step_path)
    end

    def find_microstep(microstep_name, loaded_microsteps)
      Kameleon.ui.debug("Looking for microstep #{microstep_name}")
      loaded_microsteps.each do |microstep|
        if microstep_name.eql? microstep.name
          return microstep
        end
      end
      return nil
    end

    def resolve_data_path(partial_path, step_path)
      Kameleon.ui.debug("Looking for data '#{partial_path}'")
      dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "data")
      end.flatten
      dir_search.each do |dir_path|
        real_path = Pathname.new(File.join(dir_path, partial_path)).cleanpath
        if real_path.exist?
          Kameleon.ui.debug("Register data #{real_path}")
          @data.push(real_path) unless @data.include? real_path
          return real_path
        end
        Kameleon.ui.debug("#{real_path} : nonexistent")
      end
      fail RecipeError, "Cannot found data '#{partial_path}' unsed in '#{step_path}'"
    end

    def resolve!
      unless @global.keys.include? "kameleon_uuid"
        kameleon_id = SecureRandom.uuid
        @global["kameleon_uuid"] = kameleon_id
        @global["kameleon_short_uuid"] = kameleon_id.split("-").last
      end
      # Resolve dynamically-defined variables !!
      resolved_global = Utils.resolve_vars(@global.to_yaml, @path, @global, self)
      @global.merge! YAML.load(resolved_global)

      consistency_check
      resolve_checkpoint unless @checkpoint.nil?

      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          # First pass : resolve aliases
          Kameleon.ui.debug("Resolving aliases for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each do |microstep|
            microstep.commands.map! do |cmd|
              # resolve alias
              @aliases.keys.include?(cmd.key) ? resolve_alias(cmd) : cmd
            end
          end
          # flatten for multiple-command alias + variables
          Kameleon.ui.debug("Resolving check statements for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each { |microstep| microstep.commands.flatten! }
        end
      end

      Kameleon.ui.info("Resolving variables")
      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          macrostep.resolve_variables!(@global, self)
        end
      end

      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          # Second pass : resolve variables + clean/init hooks
          macrostep.microsteps.each do |microstep|
            microstep.commands.map! do |cmd|
              resolve_hooks(cmd, macrostep, microstep)
            end
          end
          Kameleon.ui.debug("Compacting macrostep '#{macrostep.name}'")
          # remove empty steps
          macrostep.microsteps.map! do |microstep|
            microstep.commands.compact!
            microstep.commands.empty? ? nil : microstep
          end
          # remove nil values
          macrostep.microsteps.compact!
          Kameleon.ui.debug("Resolving commands for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each do |microstep|
            microstep.resolve!
          end
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
      Kameleon.ui.info("Starting recipe consistency check")
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
        required_args = %w(create apply list clear)
        missings = []
        missings = required_args - (@checkpoint.keys() & required_args)
        fail RecipeError, "Required paramater missing for checkpoint:" \
                          " #{ missings.join ' ' }" unless missings.empty?
      end
    end

    def resolve_checkpoint()
      (@checkpoint.keys - ["path"]).each do |key|
        @checkpoint[key].each do |cmd|
          cmd.string_cmd = Utils.resolve_vars(cmd.string_cmd,
                                              @checkpoint["path"],
                                              @global,
                                              self)
        end
      end
    end

    def resolve_alias(cmd)
      name = cmd.key
      aliases_cmd = @aliases.fetch(name).clone
      aliases_cmd_str = aliases_cmd.to_yaml
      args = YAML.load(cmd.string_cmd)[name]
      args = [].push(args).flatten  # convert args to array
      expected_args_number = aliases_cmd_str.scan(/@\d+/).uniq.count
      if expected_args_number != args.count
        if args.length == 0
          msg = "#{name} takes no arguments (#{args.count} given)"
        else
          msg = "#{name} takes exactly #{expected_args_number} arguments"
                " (#{args.count} given)"
        end
        raise RecipeError, msg
      end
      microstep = Microstep.new({cmd.microstep_name => aliases_cmd})
      args.each_with_index do |arg, i|
        microstep.gsub!("@#{i+1}", arg)
      end
      microstep.commands.map do |escaped_cmd|
        Command.new(YAML.load(escaped_cmd.string_cmd), cmd.microstep_name)
      end
    end

    #handle clean methods
    def resolve_hooks(cmd, macrostep, microstep)
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
          microstep_name = "_clean_#{macrostep.clean_microsteps.count}" \
                           "_#{microstep.name}"
          new_clean_microstep = Microstep.new({microstep_name => []})
          new_clean_microstep.on_checkpoint = microstep.on_checkpoint
          new_clean_microstep.commands = cmds.clone
          macrostep.clean_microsteps.unshift new_clean_microstep
          return
        elsif cmd.key.eql? "on_init"
          microstep_name = "_init_#{macrostep.init_microsteps.count}"\
                           "_#{microstep.name}"
          new_init_microstep = Microstep.new({microstep_name=> []},
                                             microstep)
          new_init_microstep.on_checkpoint = microstep.on_checkpoint
          new_init_microstep.commands = cmds.clone
          macrostep.init_microsteps.unshift new_init_microstep
          return
        else
          @sections.values.each do |section|
            section.clean_macrostep
            if cmd.key.eql? "on_#{section.name}_clean"
              microstep_name = "_clean_#{section.clean_macrostep.microsteps.count}" \
                               "_#{microstep.name}"
              new_clean_microstep = Microstep.new({microstep_name=> []})
              new_clean_microstep.commands = cmds.clone
              new_clean_microstep.on_checkpoint = microstep.on_checkpoint
              section.clean_macrostep.microsteps.unshift new_clean_microstep
              return
            elsif cmd.key.eql? "on_#{section.name}_init"
              microstep_name = "_init_#{section.init_macrostep.microsteps.count}" \
                               "_#{microstep.name}"
              new_init_microstep = Microstep.new({microstep_name=> []})
              new_init_microstep.commands = cmds.clone
              new_init_microstep.on_checkpoint = microstep.on_checkpoint
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
      Kameleon.ui.debug("Calculating microstep identifiers")
      base_salt = ""
      order = 0
      @sections.values.each do |section|
        section.sequence do |macrostep|
          macrostep.sequence do |microstep|
            if ["redo", "skip"].include? microstep.on_checkpoint
              microstep.calculate_identifier ""
            else
              base_salt = microstep.calculate_identifier base_salt
            end
            slug = "#{section.name}/#{macrostep.name}/#{microstep.name}"
            microstep.slug = slug
            microstep.order = (order += 1)
            Kameleon.ui.debug("  #{microstep.slug}: #{microstep.identifier}")
          end
        end
      end
    end

    def to_hash
      recipe_hash = {
        "name" => @name,
        "path" => @path.to_s,
        "files" => @files.map {|p| p.to_s },
        "base_recipes_files" => @base_recipes_files.map {|p| p.to_s },
        "global" => @global,
        "aliases" => @aliases,
        "data" => @data,
      }
      recipe_hash["checkpoint"] = @checkpoint unless @checkpoint.nil?
      recipe_hash["steps"] = to_array
      return recipe_hash
    end

    def display_info
      def prefix
        Kameleon.ui.shell.say " -> ", :blue
      end
      Kameleon.ui.info("Description:")
      prefix ; Kameleon.ui.info("#{@metainfo['description']}")
      Kameleon.ui.info("Path:")
      prefix ; Kameleon.ui.info("#{@path}")
      Kameleon.ui.info("Parent recipes:")
      (@base_recipes_files - [@path]).each do |base_recipe_file|
        prefix ; Kameleon.ui.info("#{base_recipe_file}")
      end
      Kameleon.ui.info("Steps:")
      @files.each do |step|
        prefix ; Kameleon.ui.info("#{step}")
      end
      Kameleon.ui.info("Data:")
      @data.each do |d|
        prefix ; Kameleon.ui.info("#{d}")
      end
      Kameleon.ui.info("Variables:")
      @global.each do |key, value|
        prefix ; Kameleon.ui.info("#{key}: #{value}")
      end
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

    def initialize(path, kwargs = {})
      super(path, kwargs)
    end

    def relative_path_from_recipe(recipe_path)
      recipe_path = Pathname.new(recipe_path)
      relative_path_tpl_repo = @path.relative_path_from(Kameleon.env.repositories_path)
      absolute_path = Pathname.new(Kameleon.env.workspace).join(relative_path_tpl_repo)
      return absolute_path.relative_path_from(recipe_path.dirname)
    end
  end
end
