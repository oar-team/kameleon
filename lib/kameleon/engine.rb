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

      @recipe.global["persistent_cache"] = @options[:enable_cache] ? "true" : "false"

      build_recipe = load_build_recipe
      # restore previous build uuid
      unless build_recipe.nil?
        %w(kameleon_uuid kameleon_short_uuid).each do |key|
          @recipe.global[key] = build_recipe["global"][key]
        end
      end
      @enable_checkpoint = @options[:enable_checkpoint]
      @enable_checkpoint = true unless @options[:from_checkpoint].nil?
      # Check if the recipe have checkpoint entry
      if @enable_checkpoint && @recipe.checkpoint.nil?
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
      unless @options[:dryrun] or @options[:dag]
        begin
          Kameleon.ui.info("Creating kameleon build directory : #{@cwd}")
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
        safe_exec_cmd(cmd.dup.gsub!("@microstep_id", microstep_id))
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

    def list_all_checkpoints
      list = ""
      @recipe.checkpoint["list"].each do |cmd|
        safe_exec_cmd(cmd, :stdout => list)
      end
      return list.split(/\r?\n/)
    end

    def list_checkpoints
      if @list_checkpoints.nil?
        checkpoints = list_all_checkpoints
        all_microsteps_ids = @recipe.microsteps.map { |m| m.identifier }
        # get sorted checkpoints by microsteps order
        @list_checkpoints = []
        all_microsteps_ids.each do |id|
          @list_checkpoints.push(id) if checkpoints.include?(id)
        end
      end
      return @list_checkpoints
    end

    def do_steps(section_name)
      section = @recipe.sections.fetch(section_name)
      section.sequence do |macrostep|
        checkpointed = false
        macrostep_time = Time.now.to_i
        if @cache then
          Kameleon.ui.debug("Starting proxy cache server for macrostep '#{macrostep.name}'...")
          # the following function start a polipo web proxy and stops a previous run
          dir_cache = @cache.create_cache_directory(macrostep.name)
          unless @cache.start_web_proxy_in(dir_cache)
            raise CacheError, "The cache process fail to start"
          end
        end
        macrostep.sequence do |microstep|
          step_prefix = "Step #{ microstep.order } : "
          Kameleon.ui.info("#{step_prefix}#{ microstep.slug }")
          if @enable_checkpoint
            if microstep.on_checkpoint == "skip"
              Kameleon.ui.msg("--> Skipped")
              next
            end
            if microstep.in_cache && microstep.on_checkpoint == "use_cache"
              Kameleon.ui.msg("--> Using checkpoint")
            else
              Kameleon.ui.msg("--> Running the step...")
              microstep.commands.each do |cmd|
                safe_exec_cmd(cmd)
              end
              unless microstep.on_checkpoint == "redo"
                unless checkpointed
                  if checkpoint_enabled?
                    Kameleon.ui.msg("--> Creating checkpoint : #{ microstep.identifier }")
                    create_checkpoint(microstep.identifier)
                    checkpointed = true
                  end
                end
              end
            end
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
        Kameleon.ui.info("Step #{macrostep.name} took: #{Time.now.to_i-macrostep_time} secs")
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
          Kameleon.ui.error("Invalid context name arguments. Expected : "\
                           "#{expected_names}")
          fail ExecError
        else
          map[context].reload
        end
      when "exec_in"
        @in_context.execute(cmd.value, kwargs)
      when "exec_out"
        @out_context.execute(cmd.value, kwargs)
      when "exec_local"
        @local_context.execute(cmd.value, kwargs)
      when "pipe"
        first_cmd, second_cmd = cmd.value
        expected_cmds = ["exec_in", "exec_out", "exec_local"]
        [first_cmd.key, second_cmd.key].each do |key|
          unless expected_cmds.include?(key)
            Kameleon.ui.error("Invalid pipe arguments. Expected : "\
                              "#{expected_cmds}")
            fail ExecError
          end
        end
        first_context = map[first_cmd.key]
        second_context = map[second_cmd.key]
        @cache.cache_cmd_raw(cmd.raw_cmd_id) if @cache
        first_context.pipe(first_cmd.value, second_cmd.value, second_context)
      when "rescue"
        first_cmd, second_cmd = cmd.value
        begin
          exec_cmd(first_cmd)
        rescue ExecError
          safe_exec_cmd(second_cmd)
        end
      when "test"
        first_cmd, second_cmd, third_cmd = cmd.value
        begin
          exec_cmd(first_cmd)
        rescue ExecError
          exec_cmd(third_cmd) unless third_cmd.nil?
        else
          exec_cmd(second_cmd)
        end
      else
        Kameleon.ui.warn("Unknown command : #{cmd.key}")
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
      message = "Error occured when executing the following command :\n"
      cmd.string_cmd.split( /\r?\n/ ).each {|m| message << "\n> #{m}" }
      if Kameleon.env.script?
        raise ExecError, message
      end
      return breakpoint(message, :enable_retry => true)
    end

    def clean(kwargs = {})
      map = {"exec_in" => @in_context,
             "exec_out" => @out_context,
             "exec_local" => @local_context}
      if kwargs.fetch(:with_checkpoint, false)
        Kameleon.ui.info("Removing all checkpoints")
        @recipe.checkpoint["clear"].each do |cmd|
          if map.keys.include? cmd.key
            begin
              exec_cmd(cmd) unless map[cmd.key].closed?
            rescue
              Kameleon.ui.warn("An error occurred while executing : #{cmd.value}")
            end
          end
        end
      end
      @recipe.sections.values.each do |section|
        next if @cleaned_sections.include?(section.name)
        Kameleon.ui.info("Cleaning #{section.name} section")
        section.clean_macrostep.sequence do |microstep|
          if @enable_checkpoint
            if microstep.on_checkpoint == "skip"
              next
            end
          end
          microstep.commands.each do |cmd|
            if map.keys.include? cmd.key
              begin
                exec_cmd(cmd) unless map[cmd.key].closed?
              rescue
                Kameleon.ui.warn("An error occurred while executing : #{cmd.value}")
              end
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

    def dag(graph, color)
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
          n_base_recipe = g_recipes.add_nodes(base_recipe_path.relative_path_from(Pathname(Dir.pwd)).to_s)
          n_base_recipe['shape'] = 'Mdiamond'
          edge = graph.add_edges(n_base_recipe, n_recipe)
          edge['style'] = 'dashed'
      end
      n_prev = n_recipe
      ["bootstrap", "setup", "export"].each do |section_name|
        section = @recipe.sections.fetch(section_name)
        g_section = graph.add_graph( "cluster S:#{ section_name }" )
        g_section['label'] = section_name.capitalize
        section.sequence do |macrostep|
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
      Kameleon.ui.info "-> Drawn DAG for #{recipe_path}"
      return graph
    end

    def build
      if @enable_checkpoint
        @from_checkpoint = @options[:from_checkpoint]
        if @from_checkpoint.nil? || @from_checkpoint == "last"
          @from_checkpoint = list_checkpoints.last
        else
          unless list_checkpoints.include?@from_checkpoint
            fail BuildError, "Unknown checkpoint hash : #{@from_checkpoint}." \
                             " Use checkpoints command to find a valid" \
                             " checkpoint"
          end
        end
        unless @from_checkpoint.nil?
          Kameleon.ui.info("Restoring last build from step : #{@from_checkpoint}")
          apply_checkpoint @from_checkpoint
          @recipe.microsteps.each do |microstep|
            microstep.in_cache = true
            if microstep.identifier == @from_checkpoint
              break
            end
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
      def find_microstep_slug_by_id(id)
        @recipe.microsteps.each do |m|
          return m.slug if m.identifier == id
        end
      end
      dict_checkpoints = []
      unless @recipe.checkpoint.nil?
        list_checkpoints.each do |id|
          slug = find_microstep_slug_by_id id
          unless slug.nil?
            dict_checkpoints.push({
              "id" => id,
              "step" => slug
            })
          end
        end
      end
      if dict_checkpoints.empty?
        puts "No checkpoint available for the recipe '#{recipe.name}'"
      else
        puts "The following checkpoints are available for  " \
                 "the recipe '#{recipe.name}':"
        tp dict_checkpoints, {"id" => {:width => 20}}, { "step" => {:width => 60}}
      end
    end
  end
end
