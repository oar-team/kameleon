require 'kameleon/recipe'
require 'kameleon/context'
require 'kameleon/persistent_cache'
module Kameleon

  class Engine
    attr_accessor :recipe
    attr_accessor :cwd
    attr_accessor :build_recipe_path
    attr_accessor :pretty_list_checkpoints

    def initialize(recipe, options)
      @options = options
      @recipe = recipe
      @cleaned_sections = []
      @cwd = @recipe.global["kameleon_cwd"]
      @build_recipe_path = File.join(@cwd, "kameleon_build_recipe.yaml")

      @recipe.global["persistent_cache"] = @options[:cache] ? "true" : "false"

      build_recipe = load_build_recipe
      # restore previous build uuid
      unless build_recipe.nil?
        %w(kameleon_uuid kameleon_short_uuid).each do |key|
          @recipe.global[key] = build_recipe["global"][key]
        end
      end

      @enable_checkpoint = !@options[:no_checkpoint]
      # Check if the recipe have checkpoint entry
      @enable_checkpoint = !@recipe.checkpoint.nil? if @enable_checkpoint

      @recipe.resolve!

      if @options[:cache] || @options[:from_cache] then
        @cache = Kameleon::Persistent_cache.instance
        @cache.cwd = @cwd
        @cache.polipo_path = @options[:proxy_path]
        @cache.name = @recipe.name
        @cache.mode = @options[:cache] ? :build : :from
        @cache.cache_path = @options[:from_cache]
        @cache.recipe_files = @recipe.files # I'm passing the Pathname objects
        @cache.recipe_path = @recipe.path

        if @recipe.global["in_context"]["proxy_cache"].nil? then
          raise BuildError, "Missing varible for in context 'proxy_cache' when using the option --cache"
        end

        if @recipe.global["out_context"]["proxy_cache"].nil? then
          raise BuildError, "Missing varible for out context 'proxy_cache' when using the option --cache"
        end

        #saving_steps_files
      end

      @in_context = nil
      begin
        Kameleon.ui.info("Creating kameleon build directory : #{@cwd}")
        FileUtils.mkdir_p @cwd
      rescue
        raise BuildError, "Failed to create build directory #{@cwd}"
      end

      Kameleon.ui.debug("Building local context [local]")
      @local_context = Context.new("local", "bash", @cwd, "", @cwd)
      Kameleon.ui.debug("Building external context [out]")
      @out_context = Context.new("out",
                                 @recipe.global["out_context"]["cmd"],
                                 @recipe.global["out_context"]["workdir"],
                                 @recipe.global["out_context"]["exec_prefix"],
                                 @cwd,
                                 :proxy_cache => @recipe.global["out_context"]["proxy_cache"])



      Kameleon.ui.debug("Building internal context [in]")
      @in_context = Context.new("in",
                                @recipe.global["in_context"]["cmd"],
                                @recipe.global["in_context"]["workdir"],
                                @recipe.global["in_context"]["exec_prefix"],
                                @cwd,
                                :proxy_cache => @recipe.global["in_context"]["proxy_cache"])
      @cache.start if @cache

    end

    def saving_steps_files
      @recipe.files.each do |file|
        Kameleon.ui.info("File #{file} loaded from the recipe")
        sleep 1
      end

    end

    def create_cache_directory(step_name)
      Kameleon.ui.debug("Creating directory for cache #{step_name}")
      directory_name = @cache.cache_dir + "/#{step_name}"
      FileUtils.mkdir_p directory_name
      directory_name
    end

    def create_checkpoint(microstep_id)
      cmd = @recipe.checkpoint["create"].gsub("@microstep_id", microstep_id)
      create_cmd = Kameleon::Command.new({"exec_out" => cmd}, "checkpoint")
      safe_exec_cmd(create_cmd, :log_level => "debug")
    end

    def apply_checkpoint(microstep_id)
      cmd = @recipe.checkpoint["apply"].gsub("@microstep_id", microstep_id)
      apply_cmd = Kameleon::Command.new({"exec_out" => cmd}, "checkpoint")
      safe_exec_cmd(apply_cmd, :log_level => "debug")
    end

    def list_all_checkpoints
      list = ""
      cmd = Kameleon::Command.new({"exec_out" => @recipe.checkpoint['list']},
                                  "checkpoint")
      safe_exec_cmd(cmd, :stdout => list)
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

        if @cache then
          # the following function start a polipo web proxy and stops a previous run
          dir_cache = @cache.create_cache_directory(macrostep.name)
          @cache.start_web_proxy_in(dir_cache)
        end

        macrostep.sequence do |microstep|
          step_prefix = "Step #{ microstep.order } : "
          Kameleon.ui.info("#{step_prefix}#{ microstep.slug }")
          if @enable_checkpoint
            if microstep.on_checkpoint == "skip"
              Kameleon.ui.info("--> Skipped")
              next
            end
            if microstep.in_cache && microstep.on_checkpoint == "use_cache"
              Kameleon.ui.info("--> Using cache this time")
            else
              Kameleon.ui.info("--> Running the step...")
              microstep.commands.each do |cmd|
                safe_exec_cmd(cmd)
              end
              unless microstep.on_checkpoint == "redo"
                Kameleon.ui.info("--> Creating checkpoint : #{ microstep.identifier }")
                create_checkpoint(microstep.identifier)
              end
            end
          else
            Kameleon.ui.info("--> Running the step...")
            microstep.commands.each do |cmd|
              safe_exec_cmd(cmd)
            end
          end
        end
      end
      @cleaned_sections.push(section.name)


      @cache.stop if @cache

    end

    def safe_exec_cmd(cmd, kwargs = {})
      finished = false
      begin
        exec_cmd(cmd, kwargs)
        finished = true
      rescue ExecError
        finished = rescue_exec_error(cmd)
      end until finished
    end

    def exec_cmd(cmd, kwargs = {})
      case cmd.key
      when "breakpoint"
        breakpoint(cmd.value)
      when "exec_in"
        skip_alert(cmd) if @in_context.nil?
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
            Kameleon.ui.error("Invalid pipe arguments. Expected "\
                          "#{expected_cmds} commands")
            fail ExecError
          end
        end
        map = {"exec_in" => @in_context,
               "exec_out" => @out_context,
               "exec_local" => @local_context,}
        first_context = map[first_cmd.key]
        second_context = map[second_cmd.key]
        @cache.cache_cmd_id(cmd.identifier) if @cache
        first_context.pipe(first_cmd.value, second_cmd.value, second_context)
      when "rescue"
        first_cmd, second_cmd = cmd.value
        begin
          exec_cmd(first_cmd)
        rescue ExecError
          exec_cmd(second_cmd)
        end
      else
        Kameleon.ui.warn("Unknown command : #{cmd.key}")
      end
    end


    def breakpoint(message, kwargs = {})
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
        answer = Kameleon.ui.ask "answer ? [" + responses.keys().join("/") + "]: "
        raise AbortError, "Execution aborted..." if answer.nil?
        answer.chomp!
        if responses.keys.include?(answer)
          Kameleon.ui.info("User choice : [#{answer}] #{responses[answer]}")
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
      return breakpoint(message, :enable_retry => true)
    end

    def clean()
      @recipe.sections.values.each do |section|
        next if @cleaned_sections.include?(section.name)
        map = {"exec_in" => @in_context,
               "exec_out" => @out_context,
               "exec_local" => @local_context}
        Kameleon.ui.info("Cleaning #{section.name} section")
        section.clean_macrostep.sequence do |microstep|
          microstep.commands.each do |cmd|
            if map.keys.include? cmd.key
              unless map[cmd.key].closed?
                begin
                  exec_cmd(cmd)
                rescue
                  Kameleon.ui.warn("An error occurred while executing : #{cmd.value}")
                end
              end
            end
          end
        end
      end
      @cache.stop_web_proxy if @options[:cache] ## stopping polipo
    end

    def clear
      clean
      unless @recipe.checkpoint.nil?
        Kameleon.ui.info("Removing all old checkpoints")
        cmd = @recipe.checkpoint["clear"]
        clear_cmd = Kameleon::Command.new({"exec_out" => cmd}, "checkpoint")
        safe_exec_cmd(clear_cmd, :log_level => "info")
      end
    end

    def build
      if @enable_checkpoint
        @from_checkpoint = @options[:from_checkpoint]
        if @from_checkpoint.nil?
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
          @out_context.reopen
          @in_context.reopen
          @local_context.reopen
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
      if @enable_checkpoint
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
