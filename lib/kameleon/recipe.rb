require 'kameleon/utils'
require 'kameleon/step'

module Kameleon

  class Recipe
    attr_accessor :path, :name, :global, :sections, :aliases, :aliases_path, \
                  :checkpoint, :checkpoint_path, :metainfo

    def initialize(path)
      @logger = Log4r::Logger.new("kameleon::[kameleon]")
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @recipe_content = File.open(@path, 'r') { |f| f.read }
      @sections = {
        "bootstrap" => Section.new("bootstrap"),
        "setup" => Section.new("setup"),
        "export" => Section.new("export"),
      }
      kameleon_id = SecureRandom.uuid
      @global = {
        "kameleon_recipe_name" => @name,
        "kameleon_recipe_dir" => File.dirname(@path),
        "kameleon_uuid" => kameleon_id,
        "kameleon_short_uuid" => kameleon_id.split("-").last,
        "kameleon_cwd" => File.join(Kameleon.env.build_path, @name),
        "in_context" => {"cmd"=> "/bin/bash"},
        "out_context" => {"cmd"=> "/bin/bash",
                         "workdir"=> File.join(Kameleon.env.build_path, @name)}
      }
      @aliases = {}
      @checkpoint = nil
      @files = []
      @logger.debug("Initialize new recipe (#{path})")
      @base_recipes_files = [@path]
      load!
    end

    def load!
      # Find recipe path
      @logger.debug("Loading #{@path}")
      fail RecipeError, "Could not find this following recipe : #{@path}" \
         unless File.file? @path
      yaml_recipe = YAML.load File.open @path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error"
      end
      # Load entended recipe variables
      yaml_recipe = load_base_recipe(yaml_recipe)
      yaml_recipe.delete("extend")

      # Load Global variables
      @global.merge!(yaml_recipe.fetch("global", {}))
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
            embedded_step = false
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
            # Detect if step is embedded
            if not args.nil?
              args.each do |arg|
                if arg.kind_of? Hash
                  if arg.flatten[1].kind_of? Array
                    embedded_step = true
                  end
                end
              end
            end
            if embedded_step
              @logger.debug("Loading embedded macrostep #{name}")
              macrostep = load_macrostep(nil, name, args)
              section.macrosteps.push(macrostep)
              next
            end
            # Load macrostep yaml
            loaded = false
            dir_to_search.each do |dir|
              macrostep_path = Pathname.new(File.join(dir, name + '.yaml'))
              if File.file?(macrostep_path)
                @logger.debug("Loading macrostep #{macrostep_path}")
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
      @logger.debug("Loading recipe metadata")
      @metainfo = {
        "description" => Utils.extract_meta_var("description", @recipe_content)
      }
    end

    def load_base_recipe(yaml_recipe)
      base_recipe_name = yaml_recipe.fetch("extend", "")
      return yaml_recipe if base_recipe_name.empty?

      ## check that the recipe has not already been loaded
      base_recipe_name << ".yaml" unless base_recipe_name.end_with? ".yaml"
      base_recipe_path = File.join(File.dirname(@path), base_recipe_name)

      ## check that the recipe has not already been loaded
      return yaml_recipe if @base_recipes_files.include? base_recipe_path

      base_recipe_path << ".yaml" unless base_recipe_path.end_with? ".yaml"
      fail RecipeError, "Could not find this following recipe : #{@recipe_path}" \
         unless File.file? @path
      base_yaml_recipe = YAML.load File.open base_recipe_path
      unless yaml_recipe.kind_of? Hash
        fail RecipeError, "Invalid yaml error"
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
      @base_recipes_files.push(Pathname.new(base_recipe_path))
      return load_base_recipe(base_yaml_recipe)
    end

    def load_aliases(yaml_recipe)
      if yaml_recipe.keys.include? "aliases"
        aliases = yaml_recipe.fetch("aliases")
        if aliases.kind_of? Hash
          @aliases = aliases
        elsif aliases.kind_of? String
          dir_search = [
            File.join(File.dirname(@path), "steps", "aliases"),
            File.join(File.dirname(@path), "aliases")
          ]
          dir_search.each do |dir_path|
            path = Pathname.new(File.join(dir_path, aliases))
            if File.file?(path)
              @logger.debug("Loading aliases #{path}")
              @aliases = YAML.load_file(path)
              @files.push(path)
              return path
            end
          end
          fail RecipeError, "Aliases file '#{path}' does not exists"
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
          dir_search = [
            File.join(File.dirname(@path), "steps", "checkpoints"),
            File.join(File.dirname(@path), "checkpoints")
          ]
          dir_search.each do |dir_path|
            path = Pathname.new(File.join(dir_path, checkpoint))
            if File.file?(path)
              @logger.debug("Loading checkpoint configuration #{path}")
              @checkpoint = YAML.load_file(path)
              @checkpoint["path"] = path.to_s
              @files.push(path)
              return path
            end
          end
          fail RecipeError, "Checkpoint configuraiton file '#{path}' " \
                            "does not exists"
        end
      end
    end

    def load_macrostep(step_path, name, args)
      if step_path.nil?
        macrostep_yaml = args
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
              resolve_hooks(cmd, macrostep, microstep)
            end
          end
          @logger.debug("Compacting macrostep '#{macrostep.name}'")
          # remove empty steps
          macrostep.microsteps.map! do |microstep|
            microstep.commands.compact!
            microstep.commands.empty? ? nil : microstep
          end
          # remove nil values
          macrostep.microsteps.compact!
          @logger.debug("Resolving commands for macrostep '#{macrostep.name}'")
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
      @logger.notice("Starting recipe consistency check")
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
      %w(create apply list clear).each do |key|
        @checkpoint[key] = Utils.resolve_vars(@checkpoint[key],
                                              @checkpoint["path"],
                                              @global)
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
        "base_recipes_files" => @base_recipes_files.map {|p| p.to_s },
        "global" => @global,
        "aliases" => @aliases,
      }
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

    def get_answer(msg)
      while true
        @logger.progress_notice msg
        answer = $stdin.gets.downcase
        raise AbortError, "Execution aborted..." if answer.nil?
        answer.chomp!
        if ["y", "n" , "", "a"].include?(answer)
          if answer.eql? "y"
            return true
          elsif answer.eql? "a"
            raise AbortError, "Aborted..."
          end
          return false
        end
      end
    end

    def safe_copy_file(src, dst, force)
      if File.exists? dst
        diff = Diffy::Diff.new(dst.to_s, src.to_s, :source => "files").to_s
        unless diff.chomp.empty?
          @logger.notice("File #{} --> Already exists")
          puts Diffy::Diff.new(dst.to_s, src.to_s,
                               :source => "files",
                               :context => 1,
                               :include_diff_info => true).to_s
          msg = "overwrite #{dst} ? [y]es/[N]o/[a]bort : "
          if force || get_answer(msg)
            FileUtils.copy_file(src, dst)
          end
        end
      else
        FileUtils.mkdir_p File.dirname(dst)
        FileUtils.copy_file(src, dst)
      end
    end

    def copy_extended_recipe(recipe_name, force)
      Dir::mktmpdir do |tmp_dir|
        recipe_path = File.join(tmp_dir, recipe_name + '.yaml')
        ## copying recipe
        File.open(recipe_path, 'w+') do |file|
          extend_erb_tpl = File.join(Kameleon.env.templates_path, "extend.erb")
          tpl = ERB.new(File.open(extend_erb_tpl, 'rb') { |f| f.read })
          result = tpl.result(binding)
          file.write(result)
        end
        recipe_dst = File.join(Kameleon.env.workspace, recipe_name + '.yaml')
        safe_copy_file(recipe_path, Pathname.new(recipe_dst), force)
      end
    end

    def copy_template(force)
      ## copying steps
      files2copy = @base_recipes_files + @files
      files2copy.each do |path|
        relative_path = path.relative_path_from(Kameleon.env.templates_path)
        dst = File.join(Kameleon.env.workspace, relative_path)
        safe_copy_file(path, dst, force)
      end
    end
  end
end
