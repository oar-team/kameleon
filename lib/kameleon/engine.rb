require 'kameleon/recipe'
require 'kameleon/context'
require 'kameleon/persistent_cache'
require 'graphviz'


module Kameleon

  class Engine
    attr_accessor :recipe
    attr_accessor :cwd

    def initialize(recipe, options)
      @options = options
      @recipe = recipe
      @cleaned_sections = []
      @cwd = @recipe.global["kameleon_cwd"]
      @build_recipe_path = File.join(@cwd, ".build_recipe")

      @recipe.global["checkpointing_enabled"] = @options[:enable_checkpointing] ? "true" : "false"
      @recipe.global["persistent_cache"] = @options[:enable_cache] ? "true" : "false"

      build_recipe = load_build_recipe
      # restore previous build uuid
      unless build_recipe.nil?
        %w(kameleon_uuid kameleon_short_uuid).each do |key|
          @recipe.global[key] = build_recipe["global"][key]
        end
      end
      @checkpointing = @options[:enable_checkpointing]
      # Check if the recipe have checkpoint entry
      if @checkpointing && @recipe.checkpoint.nil?
        fail BuildError, "Checkpoint is unavailable for this recipe"
      end

      if @options[:enable_cache] || @options[:from_cache] then
        if @recipe.global["in_context"]["proxy_cache"].nil? then
          raise BuildError, "Missing variable for in context 'proxy_cache' when using the option --cache"
        end

        if @recipe.global["out_context"]["proxy_cache"].nil? then
          raise BuildError, "Missing variable for out context 'proxy_cache' when using the option --cache"
        end
        @cache = Kameleon::Persistent_cache.instance

        @cache.cwd = @cwd
        @cache.polipo_path = @options[:polipo_path]
        @cache.name = @recipe.name
        @cache.mode = @options[:enable_cache] ? :build : :from
        @cache.offline = @options[:proxy_offline]
        @cache.cache_path = @options[:from_cache]
        @cache.recipe_path = @recipe.path
        @cache.archive_format = @options[:cache_archive_compression]
        if @options[:proxy] != ""
          @cache.polipo_cmd_options['parentProxy'] = @options[:proxy]
        end
        if @options[:proxy_credentials] != ""
          @cache.polipo_cmd_options['parentAuthCredentials'] = @options[:proxy_credentials]
        end

        @recipe.global["proxy_local"] = "127.0.0.1:#{@cache.polipo_port}"
        @recipe.global["proxy_out"] = "#{@recipe.global['out_context']['proxy_cache']}:#{@cache.polipo_port}"
        @recipe.global["proxy_in"] = "#{@recipe.global['in_context']['proxy_cache']}:#{@cache.polipo_port}"
      elsif @options[:proxy] != ""
        if @options[:proxy_credentials] != ""
          proxy_url = "#{@options[:proxy_credentials]}@#{@options[:proxy]}"
        else
          proxy_url = "#{@options[:proxy]}"
        end
        @recipe.global["proxy_local"] = @recipe.global["proxy_out"] = @recipe.global["proxy_in"] = proxy_url
      end

      @recipe.resolve!

      if @options[:enable_cache] || @options[:from_cache] then
        @cache.recipe_files = @recipe.all_files
      end
      unless @options[:no_create_build_dir]
        begin
          Kameleon.ui.info("Creating kameleon build directory: #{@cwd}")
          FileUtils.mkdir_p @cwd
        rescue
          raise BuildError, "Failed to create build directory #{@cwd}"
        end
        @cache.start if @cache
        build_contexts
      end
    end

    def build_contexts
      lazyload = @options.fetch(:lazyload, true)
      fail_silently = @options.fetch(:fail_silently, false)

      Kameleon.ui.debug("Building local context [local]")
      @local_context = Context.new("local", "bash", "bash", @cwd, "", @cwd,
                                   @recipe.env_files,
                                   :proxy => @recipe.global["proxy_local"],
                                   :lazyload => lazyload,
                                   :fail_silently => false)
      Kameleon.ui.debug("Building external context [out]")
      @out_context = Context.new("out",
                                 @recipe.global["out_context"]["cmd"],
                                 @recipe.global["out_context"]["interactive_cmd"],
                                 @recipe.global["out_context"]["workdir"],
                                 @recipe.global["out_context"]["exec_prefix"],
                                 @cwd,
                                 @recipe.env_files,
                                 :proxy => @recipe.global["proxy_out"],
                                 :lazyload => lazyload,
                                 :fail_silently => fail_silently)

      Kameleon.ui.debug("Building internal context [in]")
      @in_context = Context.new("in",
                                @recipe.global["in_context"]["cmd"],
                                @recipe.global["in_context"]["interactive_cmd"],
                                @recipe.global["in_context"]["workdir"],
                                @recipe.global["in_context"]["exec_prefix"],
                                @cwd,
                                @recipe.env_files,
                                :proxy => @recipe.global["proxy_in"],
                                :lazyload => lazyload,
                                :fail_silently => fail_silently)
    end

    def reload_contexts
      [@local_context, @out_context, @in_context].each do |ctx|
        ctx.reload if ctx.shell.started?
      end
    end

    def saving_steps_files
      @recipe.files.each do |file|
        Kameleon.ui.info("File #{file} loaded from the recipe")
      end

    end

    def create_cache_directory(step_name)
      Kameleon.ui.debug("Creating directory for cache #{step_name}")
      directory_name = @cache.cache_dir + "/#{step_name}"
      FileUtils.mkdir_p directory_name
      directory_name
    end

    def create_checkpoint(microstep_id)
      @recipe.checkpoint["create"].each do |cmd|
        safe_exec_cmd(cmd.dup.gsub!("@microstep_id", microstep_id), :log_level => "warn")
      end
    end

    def checkpoint_enabled?
      @recipe.checkpoint["enabled?"].each do |cmd|
        exec_cmd(cmd, :log_level => "debug")
      end
      return true
    rescue ExecError
      return false
    end

    def apply_checkpoint(microstep_id)
      @recipe.checkpoint["apply"].each do |cmd|
        safe_exec_cmd(cmd.dup.gsub!("@microstep_id", microstep_id))
      end
    end

    def list_checkpoints
      if @list_checkpoints.nil?
        # get existing checkpoints on the system
        existing_checkpoint_str = ""
        @recipe.checkpoint["list"].each do |cmd|
          safe_exec_cmd(cmd, :stdout => existing_checkpoint_str)
        end
        existing_checkpoint_ids = existing_checkpoint_str.split(/\r?\n/)
        # get sorted checkpoints by microsteps order
        @list_checkpoints = []
        @recipe.all_checkpoints.each do |checkpoint|
          @list_checkpoints.push(checkpoint) if existing_checkpoint_ids.include?(checkpoint["id"])
        end
      end
      return @list_checkpoints
    end

    def do_steps(section_name)
      section = @recipe.sections.fetch(section_name)
      section.sequence do |macrostep|
        checkpointed = false
        macrostep_time = Time.now.to_i
        macrostep_checkpoint_duration = 0
        if @cache then
          Kameleon.ui.debug("Starting proxy cache server for macrostep '#{macrostep.name}'...")
          # the following function start a polipo web proxy and stops a previous run
          dir_cache = @cache.create_cache_directory(macrostep.name)
          unless @cache.start_web_proxy_in(dir_cache)
            raise CacheError, "The cache process fail to start"
          end
        end
        macrostep.sequence do |microstep|
          microstep_time = Time.now.to_i
          microstep_checkpoint_duration = 0
          step_prefix = "Step #{ microstep.order }: "
          Kameleon.ui.info("#{step_prefix}#{ microstep.slug }")
          if @checkpointing
            if microstep.on_checkpoint == "skip"
              Kameleon.ui.msg("--> Skip microstep as requested when checkpointing is activated")
              next
            end
            if microstep.has_checkpoint_ahead and microstep.on_checkpoint != "redo"
              Kameleon.ui.msg("--> Checkpoint ahead, do nothing")
            else
              begin
              Kameleon.ui.msg("--> Running the step...")
              microstep.commands.each do |cmd|
                safe_exec_cmd(cmd)
              end
              rescue SystemExit, Interrupt
                reload_contexts
                breakpoint(nil)
              end
              if checkpoint_enabled?
                if (@options[:microstep_checkpoints].downcase == "first" and checkpointed)
                  Kameleon.ui.msg("--> Do not create a checkpoint for this microstep: macrostep already checkpointed once")
                elsif microstep.on_checkpoint == "redo"
                  Kameleon.ui.msg("--> Do not create a checkpoint for this microstep: always redo microstep")
                elsif microstep.on_checkpoint == "disabled"
                  Kameleon.ui.msg("--> Do not create a checkpoint for this microstep: disabled in the microstep definition")
                elsif not microstep.in_checkpoint_window
                  if @end_checkpoint.nil?
                    unless @begin_checkpoint.nil?
                      msg = "only after step '#{@begin_checkpoint['step']}'"
                    end
                  else
                    if @begin_checkpoint.nil?
                      msg = "not after step '#{@end_checkpoint['step']}'"
                    else
                      msg = "only between steps '#{@begin_checkpoint['step']}' and '#{@end_checkpoint['step']}'"
                    end
                  end
                  Kameleon.ui.msg("--> Do not create a checkpoint for this microstep: #{msg}")
                else
                  microstep_checkpoint_time = Time.now.to_i
                  Kameleon.ui.msg("--> Creating checkpoint: '#{@recipe.all_checkpoints.select{|c| c['id'] == microstep.identifier}.first['step']}' (#{microstep.identifier})")
                  create_checkpoint(microstep.identifier)
                  checkpointed = true
                  microstep_checkpoint_duration = Time.now.to_i - microstep_checkpoint_time
                  macrostep_checkpoint_duration += microstep_checkpoint_duration
                  Kameleon.ui.verbose("Checkpoint creation for MicroStep #{microstep.name} took: #{microstep_checkpoint_duration} secs")
                end
              else
                Kameleon.ui.msg("--> Do not create a checkpoint for this microstep: disabled in backend")
              end
            end
          else
            if microstep.on_checkpoint == "only"
              Kameleon.ui.msg("--> Skip microstep as requested when checkpointing is not activated")
              next
            else
              begin
              Kameleon.ui.msg("--> Running the step...")
              microstep.commands.each do |cmd|
                safe_exec_cmd(cmd)
              end
              rescue SystemExit, Interrupt
                reload_contexts
                breakpoint(nil)
              end
            end
          end
          Kameleon.ui.verbose("MicroStep #{microstep.name} took: #{Time.now.to_i - microstep_time - microstep_checkpoint_duration} secs")
        end
        Kameleon.ui.info("Step #{macrostep.name} took: #{Time.now.to_i - macrostep_time - macrostep_checkpoint_duration} secs")
      end
      @cleaned_sections.push(section.name)
    end

    def safe_exec_cmd(cmd, kwargs = {})
      finished = false
      begin
        exec_cmd(cmd, kwargs)
        finished = true
      rescue ContextClosed => e
        Kameleon.ui.warn("#{e.message}")
        finished = true
      rescue SystemExit, Interrupt, ExecError
        reload_contexts
        finished = rescue_exec_error(cmd)
      end until finished
    end

    def exec_cmd(cmd, kwargs = {})
      map = {"exec_in" => @in_context,
             "exec_out" => @out_context,
             "exec_local" => @local_context}
      case cmd.key
      when "breakpoint"
        breakpoint(cmd.value)
      when "reload_context"
        context = "exec_" + cmd.value
        expected_names = map.keys.map { |k| k.gsub "exec_", "" }
        unless map.keys.include? context
          Kameleon.ui.error("Invalid context name arguments. Expected: "\
                           "#{expected_names}")
          fail ExecError
        else
          map[context].reload
        end
      when "exec_in", "exec_out", "exec_local"
        if kwargs[:only_with_context] and map[cmd.key].closed?
          Kameleon.ui.debug("Not executing #{cmd.key} command (context closed): #{cmd.value}")
        else
          map[cmd.key].execute(cmd.value, kwargs)
        end
      when "pipe"
        first_cmd, second_cmd = cmd.value
        expected_cmds = ["exec_in", "exec_out", "exec_local"]
        execute = true
        [first_cmd.key, second_cmd.key].each do |key|
          unless expected_cmds.include?(key)
            Kameleon.ui.error("Invalid pipe arguments. Expected: "\
                              "#{expected_cmds}")
            fail ExecError
          end
          if kwargs[:only_with_context] and map[key].closed?
            Kameleon.ui.debug("Not executing pipe command (context closed sub command #{key})")
            execute = false
          end
        end
        if execute
          first_context = map[first_cmd.key]
          second_context = map[second_cmd.key]
          @cache.cache_cmd_raw(cmd.raw_cmd_id) if @cache
          first_context.pipe(first_cmd.value, second_cmd.value, second_context, kwargs)
        end
      when "rescue"
        unless cmd.value.length == 2
          Kameleon.ui.error("Invalid 'rescue' command arguments. Expecting 2 sub commands")
          fail ExecError
        end
        first_cmd, second_cmd = cmd.value
        begin
          exec_cmd(first_cmd, kwargs)
        rescue ExecError
          safe_exec_cmd(second_cmd, kwargs)
        end
      when "test"
        unless cmd.value.length == 2 or cmd.value.length == 3
          Kameleon.ui.error("Invalid 'test' command arguments. Expecting 2 or 3 sub commands")
          fail ExecError
        end
        first_cmd, second_cmd, third_cmd = cmd.value
        begin
          Kameleon.ui.debug("Execute test condition")
          # Drop any :only_with_context flag, so that "if" fails if a closed
          # context exception occurs. In that case, the "else" statement must
          # be executed rather than the "then" statement.
          exec_cmd(first_cmd, kwargs.reject {|k| k == :only_with_context})
        rescue ExecError
          unless third_cmd.nil?
            Kameleon.ui.debug("Execute test 'else' statment'")
            exec_cmd(third_cmd, kwargs)
          end
        else
          Kameleon.ui.debug("Execute test 'then' statment'")
          exec_cmd(second_cmd, kwargs)
        end
      when "group"
         cmds = cmd.value
         cmds.each do |cmd|
           exec_cmd(cmd, kwargs)
         end
      else
        Kameleon.ui.warn("Unknown command: #{cmd.key}")
      end
    end


    def breakpoint(message, kwargs = {})
      message = "Kameleon breakpoint!" if message.nil?
      message.split( /\r?\n/ ).each {|m| Kameleon.ui.error "#{m}" }
      enable_retry = kwargs[:enable_retry]
      msg = ""
      msg << "Press [r] to retry\n" if enable_retry
      msg << "Press [c] to continue with execution"
      msg << "\nPress [a] to abort execution"
      msg << "\nPress [l] to switch to local_context shell"
      msg << "\nPress [o] to switch to out_context shell"
      msg << "\nPress [i] to switch to in_context shell"
      responses = {"c" => "continue", "a" => "abort"}
      responses["r"] = "retry" if enable_retry
      responses.merge!({"l" => "launch local_context"})
      responses.merge!({"o" => "launch out_context"})
      responses.merge!({"i" => "launch in_context"})
      while true
        msg.split( /\r?\n/ ).each {|m| Kameleon.ui.info "#{m}" }
        if Kameleon.env.script?
          answer = "a"
        else
          answer = Kameleon.ui.ask "answer ? [" + responses.keys().join("/") + "]: "
        end
        raise AbortError, "Execution aborted..." if answer.nil?
        answer.chomp!
        if responses.keys.include?(answer)
          Kameleon.ui.info("User choice: [#{answer}] #{responses[answer]}")
          if ["o", "i", "l"].include?(answer)
            if answer.eql? "l"
              @local_context.start_shell
            elsif answer.eql? "o"
              @out_context.start_shell
            else
              @in_context.start_shell
            end
            Kameleon.ui.info("Getting back to Kameleon...")
          elsif answer.eql? "a"
            raise AbortError, "Execution aborted..."
          elsif answer.eql? "c"
            ## resetting the exit status
            @in_context.execute("true") unless @in_context.closed?
            @out_context.execute("true") unless @out_context.closed?
            @local_context.execute("true") unless @local_context.closed?
            return true
          elsif answer.eql? "r"
            Kameleon.ui.info("Retrying the previous command...")
            return false
          end
        end
      end
    end

    def rescue_exec_error(cmd)
      message = "Error occured when executing the following command:\n"
      cmd.string_cmd.split( /\r?\n/ ).each {|m| message << "\n> #{m}" }
      if Kameleon.env.script?
        raise ExecError, message
      end
      return breakpoint(message, :enable_retry => true)
    end

    def clean(kwargs = {})
      kwargs = kwargs.merge({:only_with_context => true})
      if kwargs.fetch(:with_checkpoint, false)
        Kameleon.ui.info("Removing all checkpoints")
        @recipe.checkpoint["clear"].each do |cmd|
          begin
            exec_cmd(cmd, kwargs)
          rescue
            Kameleon.ui.warn("An error occurred while executing: #{cmd.value}")
          end
        end
      end
      @recipe.sections.values.each do |section|
        next if @cleaned_sections.include?(section.name)
        Kameleon.ui.info("Cleaning #{section.name} section")
        section.clean_macrostep.sequence do |microstep|
          if @checkpointing
            if microstep.on_checkpoint == "skip"
              next
            end
          else
            if microstep.on_checkpoint == "only"
              next
            end
          end
          microstep.commands.each do |cmd|
            begin
              exec_cmd(cmd, kwargs)
            rescue
              Kameleon.ui.warn("An error occurred while executing: #{cmd.value}")
            end
          end
        end
      end
      @cache.stop_web_proxy if @options[:enable_cache] ## stopping polipo
    end

    def dryrun
      def relative_or_absolute_path(path)
        if @options[:relative]
          return path.relative_path_from(Pathname(Dir.pwd))
        else
          return path
        end
      end
      if @options[:show_checkpoints]
        if @recipe.all_checkpoints.empty?
          Kameleon.ui.shell.say "No checkpoints would be created by recipe '#{recipe.name}':"
        else
          Kameleon.ui.shell.say "The following checkpoints would be created by recipe '#{recipe.name}':"
          tp @recipe.all_checkpoints, {"id" => {:width => 20}}, { "step" => {:width => 60}}
        end
      else
        Kameleon.ui.shell.say ""
        Kameleon.ui.shell.say "#{ @recipe.name } ", :bold
        Kameleon.ui.shell.say "(#{ relative_or_absolute_path(@recipe.path) })", :cyan
        ["bootstrap", "setup", "export"].each do |section_name|
          section = @recipe.sections.fetch(section_name)
          Kameleon.ui.shell.say "[" << section.name.capitalize << "]", :red
          section.sequence do |macrostep|
            Kameleon.ui.shell.say "  "
            Kameleon.ui.shell.say "#{macrostep.name} ", :bold
            if macrostep.path
              Kameleon.ui.shell.say "(#{ relative_or_absolute_path(macrostep.path) })", :cyan
            else
              Kameleon.ui.shell.say "(internal)", :cyan
            end
            macrostep.sequence do |microstep|
              Kameleon.ui.shell.say "  --> ", :magenta
              Kameleon.ui.shell.say "#{ microstep.order } ", :green
              Kameleon.ui.shell.say "#{ microstep.name }", :yellow
            end
          end
        end
        Kameleon.ui.shell.say ""
      end
    end

    def dag(graph, color, recipes_only)
      if graph.nil?
        graph =  GraphViz::new( "G" )
      end
      recipe_path = @recipe.path.relative_path_from(Pathname(Dir.pwd)).to_s
      colorscheme = "set18"
      color = (color % 8 + 1).to_s
      g_recipes = graph.add_graph( "cluster R:recipes" )
      g_recipes['label'] = 'Recipes'
      g_recipes['style'] = 'dashed'
      n_recipe = g_recipes.add_nodes(recipe_path)
      n_recipe['label'] = recipe_path
      n_recipe['shape'] = 'Mdiamond'
      n_recipe['colorscheme'] = colorscheme
      n_recipe['color'] = color
      (@recipe.base_recipes_files - [@recipe.path]).uniq.each do |base_recipe_path|
        Kameleon.ui.debug("Dag add node #{base_recipe_path}")
        n_base_recipe = g_recipes.add_nodes(base_recipe_path.relative_path_from(Pathname(Dir.pwd)).to_s)
        n_base_recipe['shape'] = 'Mdiamond'
        edge = graph.add_edges(n_base_recipe, n_recipe)
        if base_recipe_path == @recipe.extended_recipe_file
          Kameleon.ui.debug("This is the extended recipe")
          edge['colorscheme'] = colorscheme
          edge['color'] = color
        else
          edge['style'] = 'dashed'
        end
      end
      n_prev = n_recipe
      if recipes_only
        Kameleon.ui.debug("As requested, only show recipes")
      else
        ["bootstrap", "setup", "export"].each do |section_name|
          Kameleon.ui.debug("Dag add section #{section_name}")
          section = @recipe.sections.fetch(section_name)
          g_section = graph.add_graph( "cluster S:#{ section_name }" )
          g_section['label'] = section_name.capitalize
          section.sequence do |macrostep|
            Kameleon.ui.debug("Dag add macrostep #{macrostep.name}")
            if macrostep.path.nil?
                macrostep_name = macrostep.name
            else
                macrostep_name = macrostep.path.relative_path_from(Pathname(Dir.pwd)).to_s
                macrostep_name.chomp!(".yaml")
                macrostep_name.sub!(/^steps\//, "")
            end
            g_macrostep = g_section.add_graph( "cluster M:#{ macrostep_name }")
            g_macrostep['label'] = macrostep_name
            g_macrostep['style'] = 'filled'
            g_macrostep['color'] = 'gray'
            macrostep.sequence do |microstep|
              Kameleon.ui.debug("Dag add microstep #{microstep.name}")
              n_microstep = g_macrostep.add_nodes("m:#{macrostep_name}/#{microstep.name}")
              n_microstep['label'] = microstep.name
              n_microstep['style'] = 'filled'
              n_microstep['color'] = 'white'
              edge = graph.add_edges(n_prev, n_microstep)
              edge['colorscheme'] = colorscheme
              edge['color'] = color
              n_prev = n_microstep
            end
          end
        end
        n_end = graph.add_nodes('end')
        n_end['label'] = 'END'
        n_end['shape'] = 'Msquare'
        edge = graph.add_edges(n_prev, n_end)
        edge['colorscheme'] = colorscheme
        edge['color'] = color
      end
      Kameleon.ui.info "-> Draw DAG for #{recipe_path}"
      return graph
    end

    def build
      if @checkpointing
        if @options[:from_checkpoint].nil? || @options[:from_checkpoint] == "last"
          @from_checkpoint = list_checkpoints.last
        else
          @from_checkpoint = list_checkpoints.select {|c|
            c["id"] == @options[:from_checkpoint] || c["step"] == @options[:from_checkpoint]
          }.last
          if @from_checkpoint.nil?
            fail BuildError, "Unknown checkpoint '#{@options[:from_checkpoint]}'." \
              " You may use the list checkpoints option to find a valid checkpoint."
          end
        end
        unless @from_checkpoint.nil? # no checkpoint available at all
          Kameleon.ui.info("Restoring last build from step: #{@from_checkpoint["step"]}")
          apply_checkpoint @from_checkpoint["id"]
          @recipe.microsteps.each do |microstep|
            microstep.has_checkpoint_ahead = true
            if microstep.identifier == @from_checkpoint["id"]
              break
            end
          end
        end
        @begin_checkpoint = nil
        unless @options[:begin_checkpoint].nil?
          @begin_checkpoint = @recipe.all_checkpoints.select {|c|
            c["id"] == @options[:begin_checkpoint] || c["step"] == @options[:begin_checkpoint]
          }.first
          if @begin_checkpoint.nil?
            fail BuildError, "Unknown checkpoint '#{@options[:begin_checkpoint]}'." \
              " You may use the dryrun and list checkpoints options to find a valid checkpoint."
          end
        end
        @end_checkpoint = nil
        unless @options[:end_checkpoint].nil?
          @end_checkpoint = @recipe.all_checkpoints.select {|c|
            c["id"] == @options[:end_checkpoint] || c["step"] == @options[:end_checkpoint]
          }.last
          if @end_checkpoint.nil?
            fail BuildError, "Unknown checkpoint '#{@options[:end_checkpoint]}'." \
              " You may use the dryrun and list checkpoints options to find a valid checkpoint."
          end
        end
        do_checkpoint = @begin_checkpoint.nil?
        @recipe.microsteps.each do |microstep|
          if not do_checkpoint and not @begin_checkpoint.nil? and @begin_checkpoint["id"] == microstep.identifier
            do_checkpoint = true
          end
          microstep.in_checkpoint_window = do_checkpoint
          if do_checkpoint and not @end_checkpoint.nil? and @end_checkpoint["id"] == microstep.identifier
            do_checkpoint = false
          end
        end
      end
      dump_build_recipe
      begin
        ["bootstrap", "setup", "export"].each do |section|
          do_steps(section)
        end
        @cache.stop if @cache
        clean
      rescue Exception => e
        if e.is_a?(AbortError)
          Kameleon.ui.error("Aborted...")
        elsif e.is_a?(SystemExit) || e.is_a?(Interrupt)
          Kameleon.ui.error("Interrupted...")
          @out_context.reload if @out_context.already_loaded?
          @in_context.reload  if @in_context.already_loaded?
          @local_context.reload  if @local_context.already_loaded?
        else
          Kameleon.ui.error("fatal error...")
        end
        Kameleon.ui.warn("Waiting for cleanup before exiting...")
        clean
        @out_context.close!
        @in_context.close!
        @local_context.close!
        raise e
      end
    end

    def dump_build_recipe
      File.open(@build_recipe_path, 'w') do |f|
        f.write @recipe.to_hash.to_yaml
      end
    end

    def load_build_recipe
      if File.file?(@build_recipe_path)
        result = YAML.load_file(@build_recipe_path)
        return result if result
      end
      return nil
    end

    def pretty_checkpoints_list
      list_checkpoints
      if list_checkpoints.empty?
        Kameleon.ui.shell.say "No checkpoint found for recipe '#{recipe.name}'"
      else
        Kameleon.ui.shell.say "The following checkpoints are available for recipe '#{recipe.name}':"
        tp list_checkpoints, {"id" => {:width => 20}}, { "step" => {:width => 60}}
      end
    end
  end
end
