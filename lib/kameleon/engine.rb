require 'kameleon/recipe'
require 'kameleon/context'
require 'pry'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @logger = Log4r::Logger.new("kameleon::[engine]")
      @recipe = recipe
      @recipe.check
      @recipe.resolve!
      @out_context = nil
      @in_context = nil
      @cleaned_sections = []
      @cwd = @recipe.global["kameleon_cwd"]
    end

    def do_steps(section_name)
      @logger.info("Initializing #{section_name} section")
      @recipe.sections.init.fetch(section_name).each do |cmd|
        finished = false
        begin
          exec_cmd(cmd)
          finished = true
        rescue ExecError
          finished = rescue_exec_error(cmd)
        end until finished
      end
      if @recipe.sections.fetch(section_name).empty?
        @logger.warn("Section #{section_name} is empty.")
      end
      @recipe.sections.fetch(section_name).each do |macrostep|
        begin
          @logger.info("[macrostep] #{macrostep.name}")
          macrostep.microsteps.each do |microstep|
            @logger.info("[microstepstep] #{microstep.name}")
            microstep.commands.each do |cmd|
              finished = false
              begin
                exec_cmd(cmd)
                finished = true
              rescue ExecError
                finished = rescue_exec_error(cmd)
              end until finished
            end
          end
        ensure
          unless macrostep.clean.empty?
            macrostep.clean.each { |cmd| exec_cmd(cmd) }
          end
        end
      end
      do_clean(section_name)
    end

    def exec_cmd(cmd)
      def skip_alert(cmd)
        @logger.warn("Skipping cmd '#{cmd.string_cmd}'. The in_context is" \
                     " not ready yet")
      end
      case cmd.key
      when "exec_in"
        skip_alert(cmd) if @in_context.nil?
        @in_context.execute(cmd.value) unless @in_context.nil?
      when "exec_out"
        @out_context.execute(cmd.value)
      when "exec_local"
        @local_context.execute(cmd.value)
      when "pipe"
        first_cmd, second_cmd = cmd.value
        if ((first_cmd.key == "exec_in" || second_cmd.key == "exec_in")\
             && @in_context.nil?)
          skip_alert(cmd)
        else
          expected_cmds = ["exec_in", "exec_out", "exec_local"]
          [first_cmd.key, second_cmd.key].each do |key|
            unless expected_cmds.include?(key)
              @logger.error("Invalid pipe arguments. Expected #{expected_cmds} commands")
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

    def rescue_exec_error(cmd)
      @logger.error("Error executing command : #{cmd.string_cmd}")
      msg = "Press [r] to retry, [c] to continue with execution,"\
            "[a] to abort execution"
      msg = "#{msg}, [l] to switch to local_context shell" unless @local_context.nil?
      msg = "#{msg}, [o] to switch to out_context shell" unless @out_context.nil?
      msg = "#{msg}, [i] to switch to in_context shell" unless @in_context.nil?
      responses = {"r" => "retry","c" => "continue", "a" => "abort"}
      responses.merge!({"l" => "launch local_context"}) unless @out_context.nil?
      responses.merge!({"o" => "launch out_context"}) unless @out_context.nil?
      responses.merge!({"i" => "launch in_context"}) unless @in_context.nil?
      while true
        @logger.info(msg)
        answer = $stdin.gets
        raise AbortError, "Execution aborted..." if answer.nil?
        answer.chomp!
        if responses.keys.include?(answer)
          @logger.info("User choice : [#{answer}] #{responses[answer]}")
          if ["o", "i", "l"].include?(answer)
            if answer.eql? "l"
              @local_context.start_shell
            elsif answer.eql? "o"
              @out_context.start_shell
            else
              @in_context.start_shell
            end
            @logger.info("Getting back to Kameleon ...")
          elsif answer.eql? "a"
            raise AbortError, "Execution aborted..."
          elsif answer.eql? "c"
            ## resetting the exit status
            @in_context.execute("true") unless @in_context.nil?
            @out_context.execute("true") unless @out_context.nil?
            return true
          elsif answer.eql? "r"
            @logger.info("Retrying the previous command...")
            return false
          end
        end
      end
    end

    def do_clean(section_name, fail_silent=false)
      unless @cleaned_sections.include?(section_name)
        begin
          @logger.info("Cleaning #{section_name} section")
          @recipe.sections.clean.fetch(section_name).each do |cmd|
            begin
              exec_cmd(cmd)
            rescue Exception => e
              raise e if not fail_silent
              @logger.warn("An error occurred while executing : #{cmd.value}")
            end
          end
        ensure
          @cleaned_sections.push(section_name)
        end
      end
    end

    def build
      begin
        @logger.info("Creating kameleon working directory...")
        FileUtils.mkdir_p @cwd
      rescue
        raise BuildError, "Failed to create working directory #{@cwd}"
      end
      @logger.info("Building local context [local]")
      @local_context = LocalContext.new("local", @cwd)
      begin
        @logger.info("Building external context [out]")
        @out_context = Context.new("out",
                                   @recipe.global["out_context"]["cmd"],
                                   @recipe.global["out_context"]["workdir"],
                                   @recipe.global["out_context"]["exec_prefix"],
                                   @cwd)
        do_steps("bootstrap")
        @logger.info("Building internal context [in]")
        @in_context = Context.new("in",
                                  @recipe.global["in_context"]["cmd"],
                                  @recipe.global["in_context"]["workdir"],
                                  @recipe.global["in_context"]["exec_prefix"],
                                  @cwd)
        do_steps("setup")
        do_steps("export")
      rescue Exception => e
        @out_context.reopen if !@out_context.nil? && @out_context.closed?
        @in_context.reopen if !@in_context.nil? && @in_context.closed?
        @local_context.reopen if !@local_context.nil? && @local_context.closed?
        unless @out_context.nil? and @in_context.nil?
          @logger.warn("Waiting for cleanup before exiting...")
          ["bootstrap", "setup", "export"].each do |section_name|
            do_clean(section_name, true)
          end
          @out_context.close! unless @out_context.nil?
          @in_context.close! unless @in_context.nil?
          @local_context.close! unless @local_context.nil?
        end
        raise e
      end
    end
  end
end
