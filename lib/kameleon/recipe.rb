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
    attr_accessor :extended_recipe_file
    attr_accessor :base_recipes_files
    attr_accessor :data_files
    attr_accessor :env_files
    attr_accessor :cli_global

    def initialize(path, kwargs = {})
      @path = Pathname.new(File.expand_path(path))
      if not @path.exist? and @path.extname != ".yaml"
        @path = Pathname.new(File.expand_path(path + ".yaml"))
      end
      @name = (@path.basename ".yaml").to_s
      @recipe_content = File.open(@path, 'r') { |f| f.read }
      @sections = {
        "bootstrap" => Section.new("bootstrap"),
        "setup" => Section.new("setup"),
        "export" => Section.new("export"),
      }
      @cli_global = Kameleon.env.global.clone
      @cli_global.each do |k,v|
        Kameleon.ui.warn("CLI Global variable override: #{k} => #{v}")
      end

      @global = {
        "kameleon_recipe_name" => @name,
        "kameleon_recipe_dir" => File.dirname(@path),
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
        "in_context" => {"cmd" => "/bin/bash", "proxy_cache" => "127.0.0.1"},
        "out_context" => {"cmd" => "/bin/bash", "proxy_cache" => "127.0.0.1"},
        "proxy_local" => "",
        "proxy_out" => "",
        "proxy_in" => "",
      }
      @aliases = {}
      @checkpoint = nil
      @step_files = []
      Kameleon.ui.verbose("Initialize new recipe (#{path})")
      @base_recipes_files = [@path]
      @data_files = []
      @env_files = []
      @steps_dirs = []
      load! :strict => false
    end

    def update_steps_dirs()
      # Where we can find steps
      @steps_dirs = @base_recipes_files.map do |recipe_path|
        get_steps_dirs(recipe_path)
      end.flatten!
    end

    def get_steps_dirs(recipe_path)
      relative_path = recipe_path.to_s.gsub(Kameleon.env.root_dir.to_s + '/', '')
      if relative_path.eql? recipe_path.to_s
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
        steps_dirs.push(File.expand_path(File.join(p.to_s, 'steps')))
        steps_dirs.push(File.expand_path(File.join(p.to_s, '.steps')))
      end
      steps_dirs.select! { |x| File.exists? x }
    end

    def load!(kwargs = {})
      # Find recipe path
      Kameleon.ui.verbose("Loading #{@path}")
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load_file @path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error : #{@path}"
      end

      update_steps_dirs()

      extended_recipe_name = yaml_recipe.fetch("extend", "")
      unless extended_recipe_name.nil?
        extended_recipe_name << ".yaml" unless extended_recipe_name.end_with? ".yaml"
        @extended_recipe_file = Pathname.new(File.expand_path(File.join(File.dirname(path), extended_recipe_name)))
      end

      # Load extended recipe variables
      yaml_recipe = load_base_recipe(yaml_recipe, @path)
      yaml_recipe.delete("extend")

      # Where we can find steps
      @steps_dirs = @base_recipes_files.map do |recipe_path|
        get_steps_dirs(recipe_path)
      end.flatten!
      @steps_dirs.uniq!

      # Set default value for in_ctx and out_ctx options
      %w(out_context in_context).each do |context_name|
        unless yaml_recipe.keys.include? "global"
          yaml_recipe["global"] = {}
        end
        unless yaml_recipe["global"].keys.include? context_name
          yaml_recipe["global"][context_name] = {}
        end
        @global[context_name].merge!(yaml_recipe["global"][context_name])
        yaml_recipe["global"][context_name] = @global[context_name]
        unless yaml_recipe["global"][context_name].keys.include? "interactive_cmd"
          yaml_recipe["global"][context_name]["interactive_cmd"] = yaml_recipe["global"][context_name]['cmd']
        end
      end
      # Load Global variables
      @global.merge!(yaml_recipe.fetch("global", {}))
      # merge cli variable with recursive variable overload
      @global = Utils.overload_merge(@global, @cli_global)

      # Resolve dynamically-defined variables !!
      resolved_global = Utils.resolve_vars(@global.to_yaml, @path, @global, self, kwargs)
      resolved_global = @global.merge YAML.load(resolved_global)
      Kameleon.ui.debug("Resolved_global: #{resolved_global}")
      # Loads aliases
      load_aliases(yaml_recipe)
      # Load env files
      load_env_files(yaml_recipe)
      # Loads checkpoint configuration
      load_checkpoint_config(yaml_recipe)
      include_steps = resolved_global['include_steps']
      include_steps ||= []
      include_steps.push ''
      include_steps.flatten!
      include_steps.compact!
      Kameleon.ui.debug("include steps: #{include_steps}")
      @sections.values.each do |section|
        dir_to_search = @steps_dirs.map do |steps_dir|
          include_steps.map do |path|
            [File.join(steps_dir, section.name, path),
              File.join(steps_dir, path)]
          end
        end.flatten.select { |x| File.exists? x }
        Kameleon.ui.debug("Directory to search for steps:  #{dir_to_search}")

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
              Kameleon.ui.verbose("Loading embedded macrostep #{name}")
              macrostep = load_macrostep(nil, name, args, kwargs)
              section.macrosteps.push(macrostep)
              next
            end
            # Load macrostep yaml
            loaded = false
            dir_to_search.each do |dir|
              macrostep_path = Pathname.new(File.join(dir, name + '.yaml'))
              if File.file?(macrostep_path)
                Kameleon.ui.verbose("Loading macrostep #{macrostep_path}")
                macrostep = load_macrostep(macrostep_path, name, args, kwargs)
                section.macrosteps.push(macrostep)
                @step_files.push(macrostep_path)
                Kameleon.ui.verbose("Macrostep '#{name}' found in this path: " \
                                  "#{macrostep_path}")
                loaded = true
                break
              else
                Kameleon.ui.verbose("Macrostep '#{name}' not found in this path: " \
                              "#{macrostep_path}")
              end
            end
            fail RecipeError, "Step #{name} not found" unless loaded
          end
        end
      end
      Kameleon.ui.verbose("Loading recipe metadata")
      @metainfo = {
        "description" => Utils.extract_meta_var("description", @recipe_content)
      }
    end

    def load_base_recipe(yaml_recipe, path)

      base_recipe_name = yaml_recipe.fetch("extend", "")
      return yaml_recipe if base_recipe_name.empty?

      # resolve variable in extends to permit backend selection
      base_recipe_name = Utils.resolve_simple_vars_once(
          base_recipe_name, Utils.overload_merge(load_global(yaml_recipe, path), @cli_global))

      ## check that the recipe has not already been loaded
      base_recipe_name << ".yaml" unless base_recipe_name.end_with? ".yaml"
      base_recipe_path = File.join(File.dirname(path), base_recipe_name)

      ## check that the recipe has not already been loaded
      return yaml_recipe if @base_recipes_files.include? base_recipe_path

      @base_recipes_files.push(Pathname.new(File.expand_path(base_recipe_path)))
      update_steps_dirs()

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
        if ["aliases", "checkpoint", "env"].include? key
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
          base_section = load_global(base_yaml_recipe, base_recipe_path)
          recipe_section = load_global(yaml_recipe, path)
          # manage recursive variable overload
          base_yaml_recipe[key] = Utils.overload_merge(base_section, recipe_section)
        end
      end
      return load_base_recipe(base_yaml_recipe, base_recipe_path)
    end

    def load_global(yaml_recipe, recipe_path)
      global = {}
      if yaml_recipe.keys.include? "global"
        global_loaded = yaml_recipe.fetch("global", {})
        global_loaded = {} if global_loaded.nil?
        if global_loaded.kind_of? Hash
          global_loaded.each do |key, value|
            if key.eql? "include"
              global_to_include = load_include_global(value, recipe_path)
              global.merge!(global_to_include)
            else
              global[key] = value
            end
          end
        end
      end
      return global
    end

    def load_include_global(yaml_include, recipe_path)
      def load_global_file(global_file, recipe_path)
        def try_to_load(absolute_path)
          if File.file?(absolute_path)
            global_to_include = YAML.load_file(absolute_path)
            if global_to_include.kind_of? Hash
              @step_files.push(absolute_path)
              return global_to_include
            else
              fail RecipeError, "Global should be a Hash. (check #{absolute_path})"
            end
          end
        end
        ## check that the recipe has not already been loaded
        global_file << ".yaml" unless global_file.end_with? ".yaml"

        dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "global")
        end.flatten
        dir_search.unshift(File.join(File.dirname(recipe_path)))
        # try relative/absolute path
        if Pathname.new(global_file).absolute?
          global_to_include = try_to_load(global_file)
          unless global_to_include.nil?
            return global_to_include
          else
            fail RecipeError, "File '#{global_file}' not found"
          end
        else
          dir_search.each do |dir_path|
            absolute_path = Pathname.new(File.join(dir_path, global_file))
            global_to_include = try_to_load(absolute_path)
            unless global_to_include.nil?
              return global_to_include
            end
          end
        end
        rel_dir_search = dir_search.map do |steps_dir|
          Pathname.new(steps_dir).relative_path_from(Pathname(Dir.pwd)).to_s
        end.flatten
        fail RecipeError, "File '#{global_file}' not found here #{rel_dir_search}"
      end

      global_hash = {}
      if yaml_include.kind_of? String
        list_files = [yaml_include]
      elsif yaml_include.kind_of? Array
        list_files = []
        yaml_include.each do |value|
          if value.kind_of? String
            list_files.push(value)
          end
        end
      else
        return global_hash
      end
      list_files.each do |includes_file|
        filename = includes_file
        if includes_file.start_with?("-")
          filename = includes_file[1..-1]
        end
        begin
          new_global = load_global_file(filename, recipe_path)
          global_hash.merge!(new_global)
        rescue
          unless includes_file.start_with?("-")
            raise
          end
        end
      end
      return global_hash
    end

    def load_aliases(yaml_recipe)
      def load_aliases_file(aliases_file)
        dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "aliases")
        end.flatten
        dir_search.each do |dir_path|
          path = Pathname.new(File.join(dir_path, aliases_file))
          if File.file?(path)
            Kameleon.ui.verbose("Loading aliases #{path}")
            @aliases.merge!(YAML.load_file(path))
            @step_files.push(path)
            return path
          end
        end
        fail RecipeError, "Aliases file for recipe '#{@path}' does not exists"
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

    def load_env_files(yaml_recipe)
      def add_env_file(env_file)
        dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "env")
        end.flatten
        dir_search.each do |dir_path|
          path = Pathname.new(File.join(dir_path, env_file))
          if File.file?(path)
            Kameleon.ui.verbose("Adding env file #{path}")
            @env_files.push(path)
            return path
          end
        end
        fail RecipeError, "The env file script '#{env_file}' does not exists "\
                          "in any of these directories: #{dir_search}"
      end
      if yaml_recipe.keys.include? "env"
        env_content = yaml_recipe.fetch("env")
        if env_content.kind_of? String
          add_env_file(env_content)
        elsif env_content.kind_of? Array
          env_content.each do |env_file|
            add_env_file(env_file)
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
              Kameleon.ui.verbose("Loading checkpoint configuration #{path}")
              @checkpoint = YAML.load_file(path)
              @checkpoint["path"] = path.to_s
              @step_files.push(path)
              break
            end
          end
          fail RecipeError, "Checkpoint configuraiton file '#{checkpoint}' " \
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
      return Macrostep.new(name, loaded_microsteps, local_variables, step_path)
    end

    def find_microstep(microstep_name, loaded_microsteps)
      Kameleon.ui.verbose("Looking for microstep #{microstep_name}")
      loaded_microsteps.each do |microstep|
        if microstep_name.eql? microstep.name
          return microstep
        end
      end
      return nil
    end

    def resolve_data_path(partial_path, step_path)
      Kameleon.ui.verbose("Looking for data '#{partial_path}'")
      dir_search = @steps_dirs.map do |steps_dir|
          File.join(steps_dir, "data")
      end.flatten
      dir_search.each do |dir_path|
        real_path = Pathname.new(File.join(dir_path, partial_path)).cleanpath
        if real_path.exist?
          Kameleon.ui.verbose("Register data #{real_path}")
          @data_files.push(real_path) unless @data_files.include? real_path
          return real_path
        end
        Kameleon.ui.verbose("#{real_path} : nonexistent")
      end
      fail RecipeError, "Cannot find data '#{partial_path}' used in '#{step_path}'"
    end

    def resolve!(kwargs = {})
      Kameleon.ui.verbose("Resolving recipe...")
      unless @global.keys.include? "kameleon_uuid"
        kameleon_id = SecureRandom.uuid
        @global["kameleon_uuid"] = kameleon_id
        @global["kameleon_short_uuid"] = kameleon_id.split("-").last
      end
      # Resolve dynamically-defined variables !!
      resolved_global = Utils.resolve_vars(@global.to_yaml, @path, @global, self, kwargs)
      @global.merge! YAML.load(resolved_global)

      consistency_check
      resolve_checkpoint unless @checkpoint.nil?

      Kameleon.ui.verbose("Resolving aliases")
      @sections.values.each do |section|
        section.macrosteps.each do |macrostep|
          # First pass : resolve aliases
          Kameleon.ui.debug("Resolving aliases for macrostep '#{macrostep.name}'")
          macrostep.microsteps.each do |microstep|
            microstep.commands.map! do |cmd|
              resolve_alias(cmd)
            end
            # flatten for multiple-command alias + variables
            microstep.commands.flatten!
          end
        end
      end

      Kameleon.ui.verbose("Resolving variables")
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
      flatten_data

      Kameleon.ui.verbose("Recipe is resolved")
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
      Kameleon.ui.verbose("Starting recipe consistency check")
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
      if @aliases.keys.include?(name) 
        Kameleon.ui.debug("Resolving alias '#{name}'")
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
        aliases_cmd.map do |c|
          nc = Command.new(c, cmd.microstep_name)
          args.each_with_index do |arg, i|
            nc.gsub!("@#{i+1}", arg)
          end
          resolve_alias(nc)
        end 
      elsif cmd.value.kind_of?(Array)
        Kameleon.ui.debug("Search for aliases in the sub-commands of '#{name}'")
        cmd.value.map!{ |cmd| resolve_alias(cmd) }.flatten!
        cmd.remaster_string_cmd_from_value!
      else
        Kameleon.ui.debug("Leaf command '#{name}' is not an alias")
        cmd
      end
    end

    #handle clean methods
    def resolve_hooks(cmd, macrostep, microstep)
      if (cmd.key =~ /on_(.*)clean/ || cmd.key =~ /on_(.*)init/)
        cmds = []
        if cmd.value.kind_of?(Array)
          cmds = cmd.value.map do |cmd|
            resolve_alias(cmd)
          end
          cmds.flatten!
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

    def flatten_data
      files = []
      @data_files.each do |d|
        if d.directory?
          Find.find("#{d}") do |f|
            files.push(Pathname.new(f)) unless File.directory? f
          end
        else
          files.push(d)
        end
      end
      @data_files = files.uniq
    end


    def to_hash
      recipe_hash = {
        "name" => @name,
        "path" => @path.to_s,
        "base_recipes_files" => @base_recipes_files.map {|p| p.to_s },
        "step_files" => @step_files.map {|p| p.to_s },
        "env_files" => @env_files.map {|p| p.to_s },
        "data_files" => @data_files.map {|p| p.to_s },
        "global" => @global,
        "aliases" => @aliases,
      }
      recipe_hash["checkpoint"] = @checkpoint unless @checkpoint.nil?
      recipe_hash["steps"] = to_array
      return recipe_hash
    end

    def display_info(do_relative_path)
      def prefix
        Kameleon.ui.shell.say " -> ", :magenta
      end
      def relative_or_absolute_path(do_relative_path, path)
        if do_relative_path
          return path.relative_path_from(Pathname(Dir.pwd))
        else
          return path
        end
      end
      Kameleon.ui.shell.say "--------------------"
      Kameleon.ui.shell.say "[Name]", :red
      prefix ; Kameleon.ui.shell.say "#{@name}"
      Kameleon.ui.shell.say "[Path]", :red
      prefix ; Kameleon.ui.shell.say relative_or_absolute_path(do_relative_path, @path), :cyan
      Kameleon.ui.shell.say "[Description]", :red
      prefix ; Kameleon.ui.shell.say "#{@metainfo['description']}"
      Kameleon.ui.shell.say "[Parent recipes]", :red
      (@base_recipes_files - [@path]).each do |base_recipe_file|
        prefix ; Kameleon.ui.shell.say relative_or_absolute_path(do_relative_path, base_recipe_file), :cyan
      end
      Kameleon.ui.shell.say "[Steps]", :red
      @step_files.each do |step|
        prefix ; Kameleon.ui.shell.say relative_or_absolute_path(do_relative_path, step), :cyan
      end
      Kameleon.ui.shell.say "[Data]", :red
      @data_files.each do |d|
        prefix ; Kameleon.ui.shell.say relative_or_absolute_path(do_relative_path, d), :cyan
      end
      Kameleon.ui.shell.say "[Environment scripts]", :red
      @env_files.each do |d|
        prefix ; Kameleon.ui.shell.say relative_or_absolute_path(do_relative_path, d), :cyan
      end
      Kameleon.ui.shell.say "[Variables]", :red
      @global.sort.map do |key, value|
        value = "\n" if value.to_s.empty?
        prefix ; Kameleon.ui.shell.say "#{key}: ", :yellow
        Kameleon.ui.shell.say "#{value}"
      end
    end

    def to_array
      array = []
      @sections.values.each do |section|
        section.to_array.each { |m|  array.push m }
      end
      return array
    end

    def all_files
      return @base_recipes_files + @step_files + @data_files + @env_files
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
