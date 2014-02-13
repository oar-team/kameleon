require 'kameleon/recipe'
require 'kameleon/context'


module Kameleon

  class Engine
    attr_accessor :recipe, :cwd, :build_recipe_path, :pretty_list_checkpoints

    def initialize(recipe, options)
      @options = options
      @logger = Log4r::Logger.new("kameleon::[engine]")
      @recipe = recipe
      @cleaned_sections = []
      @cwd = @recipe.global["kameleon_cwd"]
      @build_recipe_path = File.join(@cwd, "kameleon_build_recipe.yaml")

      build_recipe = load_build_recipe
      # restore previous build uuid
      unless build_recipe.nil?
        # binding.pry
        %w(kameleon_uuid kameleon_short_uuid).each do |key|
          @recipe.global[key] = build_recipe["global"][key]
        end
      end

      @enable_checkpoint = !@options[:no_checkpoint]
      # Check if the recipe have checkpoint entry
      @enable_checkpoint = !@recipe.checkpoint.nil? if @enable_checkpoint

      @recipe.resolve!
      @in_context = nil
      begin
        @logger.notice("Creating kameleon working directory : #{@cwd}")
        FileUtils.mkdir_p @cwd
      rescue
        raise BuildError, "Failed to create working directory #{@cwd}"
      end
      @logger.notice("Building local context [local]")
      @local_context = Context.new("local", "bash", @cwd, "", @cwd)
      @logger.notice("Building external context [out]")
      @out_context = Context.new("out",
                                 @recipe.global["out_context"]["cmd"],
                                 @recipe.global["out_context"]["workdir"],
                                 @recipe.global["out_context"]["exec_prefix"],
                                 @cwd)
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
        macrostep.sequence do |microstep|
          @logger.notice("Step #{ microstep.order } : #{ microstep.slug }")
          @logger.notice(" ---> #{ microstep.identifier }")
          if @enable_checkpoint
            if microstep.on_checkpoint == "skip"
              @logger.notice(" ---> Skipped")
              next
            end
            if microstep.in_cache && microstep.on_checkpoint == "use_cache"
              @logger.notice(" ---> Using cache")
            else
              @logger.notice(" ---> Running step")
              microstep.commands.each do |cmd|
                safe_exec_cmd(cmd)
              end
              unless microstep.on_checkpoint == "redo"
                @logger.notice(" ---> Creating checkpoint : #{ microstep.identifier }")
                create_checkpoint(microstep.identifier)
              end
            end
          else
            @logger.notice(" ---> Running step")
            microstep.commands.each do |cmd|
              safe_exec_cmd(cmd)
            end
          end
        end
      end
      @cleaned_sections.push(section.name)
    end

    def safe_exec_cmd(cmd, kwargs = {})
      finished = false
      begin
        exec_cmd(cmd, kwargs)
        finished = true
      rescue ExecError
        finished = rescue_exec_error(cmd)
        @logger.notice("Retrying the previous command...")
      end until finished
    end

    def exec_cmd(cmd, kwargs = {})
      def skip_alert(cmd)
        @logger.warn("Skipping cmd '#{cmd.string_cmd}'. The in_context is" \
                     " not ready yet")
      end
      case cmd.key
      when "breakpoint"
        breakpoint(cmd.value, )
      when "exec_in"
        skip_alert(cmd) if @in_context.nil?
        @in_context.execute(cmd.value, kwargs) unless @in_context.nil?
      when "exec_out"
        @out_context.execute(cmd.value, kwargs)
      when "exec_local"
        @local_context.execute(cmd.value, kwargs)
      when "pipe"
        first_cmd, second_cmd = cmd.value
        if ((first_cmd.key == "exec_in" || second_cmd.key == "exec_in")\
             && @in_context.nil?)
          skip_alert(cmd)
        else
          expected_cmds = ["exec_in", "exec_out", "exec_local"]
          [first_cmd.key, second_cmd.key].each do |key|
            unless expected_cmds.include?(key)
              @logger.error("Invalid pipe arguments. Expected "\
                            "#{expected_cmds} commands")
              fail ExecError
            end
          end
          map = {"exec_in" => @in_context,
                 "exec_out" => @out_context,
                 "exec_local" => @local_context,}
          first_context = map[first_cmd.key]
          second_context = map[second_cmd.key]
          first_context.pipe(first_cmd.value, second_cmd.value, second_context)
        end
      else
        @logger.warn("Unknown command : #{cmd.key}")
      end
    end


    def breakpoint(message, kwargs = {})
      message.split( /\r?\n/ ).each {|m| @logger.error "#{m}" }
      enable_retry = kwargs[:enable_retry]
      msg = ""
      msg << "Press [r] to retry\n" if enable_retry
      msg << "Press [c] to continue with execution"
      msg << "\nPress [a] to abort execution"
      msg << "\nPress [l] to switch to local_context shell" unless @local_context.nil?
      msg << "\nPress [o] to switch to out_context shell" unless @out_context.nil?
      msg << "\nPress [i] to switch to in_context shell" unless @in_context.nil?
      responses = {"c" => "continue", "a" => "abort"}
      responses["r"] = "retry" if enable_retry
      responses.merge!({"l" => "launch local_context"}) unless @out_context.nil?
      responses.merge!({"o" => "launch out_context"}) unless @out_context.nil?
      responses.merge!({"i" => "launch in_context"}) unless @in_context.nil?
      while true
        msg.split( /\r?\n/ ).each {|m| @logger.notice "#{m}" }
        @logger.progress "answer ? [" + responses.keys().join("/") + "]: "
        answer = $stdin.gets
        raise AbortError, "Execution aborted..." if answer.nil?
        answer.chomp!
        if responses.keys.include?(answer)
          @logger.notice("User choice : [#{answer}] #{responses[answer]}")
          if ["o", "i", "l"].include?(answer)
            if answer.eql? "l"
              @local_context.start_shell
            elsif answer.eql? "o"
              @out_context.start_shell
            else
              @in_context.start_shell
            end
            @logger.notice("Getting back to Kameleon ...")
          elsif answer.eql? "a"
            raise AbortError, "Execution aborted..."
          elsif answer.eql? "c"
            ## resetting the exit status
            @in_context.execute("true") unless @in_context.nil?
            @out_context.execute("true") unless @out_context.nil?
            return true
          elsif answer.eql? "r"
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

    def finish_clean()
      @recipe.sections.values.each do |section|
        next if @cleaned_sections.include?(section.name)
        begin
          @logger.notice("Cleaning #{section.name} section")
          section.clean_macrostep.sequence do |microstep|
            microstep.commands.each do |cmd|
              begin
                exec_cmd(cmd)
              rescue
                @logger.warn("An error occurred while executing : #{cmd.value}")
              end
            end
          end
        end
      end
    end

    def clear
      @recipe.sections.values.each do |section|
        @logger.notice("Cleaning #{section.name} section")
        section.clean_macrostep.sequence do |microstep|
          microstep.commands.each do |cmd|
            if (cmd.key == "exec_out" || cmd.key == "exec_local")
              begin
                exec_cmd(cmd)
              rescue
                @logger.warn("An error occurred while executing : #{cmd.value}")
              end
            end
          end
        end
      end
      unless @recipe.checkpoint.nil?
        @logger.notice("Removing all old checkpoints")
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
          @logger.notice("Restoring last build from step : #{@from_checkpoint}")
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
        do_steps("bootstrap")
        @logger.notice("Building internal context [in]")
        @in_context = Context.new("in",
                                  @recipe.global["in_context"]["cmd"],
                                  @recipe.global["in_context"]["workdir"],
                                  @recipe.global["in_context"]["exec_prefix"],
                                  @cwd)
        do_steps("setup")
        do_steps("export")
      rescue Exception => e
        @logger.warn("Waiting for cleanup before exiting...")
        @out_context.reopen if !@out_context.nil?
        @in_context.reopen if !@in_context.nil?
        @local_context.reopen if !@local_context.nil?
        finish_clean
        @out_context.close! unless @out_context.nil?
        @in_context.close! unless @in_context.nil?
        @local_context.close! unless @local_context.nil?
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
