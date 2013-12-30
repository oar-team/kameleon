require 'kameleon/recipe'
require 'kameleon/context'
require 'pry'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @recipe = recipe
      @recipe.check
      @recipe.resolve!
      @out_context = nil
      @in_context = nil
      @cleaned_sections = []
      @cwd = @recipe.global["kameleon_cwd"]
    end

    def do_steps(section_name)
      unless @recipe.sections.key?(section_name)
        Kameleon.ui.warn "Missing #{section_name} section. Skip"
        return
      end
      Kameleon.ui.confirm "Starting section: #{section_name}"
      @recipe.sections.fetch(section_name).each do |macrostep|
        begin
          macrostep.microsteps.each do |microstep|
            Kameleon.ui.confirm "-> Executing #{macrostep.name} : #{microstep.name}"
            microstep.commands.each do |cmd|
              finished = false
              begin
                exec_cmd(cmd)
                finished = true
              rescue ExecError
                answer = rescue_exec_error(cmd)
                if answer.eql? "a"
                  raise BuildError, "Execution aborted..."
                elsif answer.eql? "c"
                  ## resetting the exit status
                  @in_context.execute("true") unless @in_context.nil?
                  @out_context.execute("true") unless @out_context.nil?
                  finished = true
                elsif answer.eql? "r"
                  Kameleon.ui.confirm "Retrying the previous command..."
                end
              end until finished
            end
          end
        ensure
          unless macrostep.clean.empty?
            macrostep.clean.each { |cmd| exec_cmd(cmd) }
          end
        end
      end
    end

    def exec_cmd(cmd)
      case cmd.key
      when "exec_in"
        if @in_context.nil?
          Kameleon.ui.warn "Skipping cmd '#{cmd.inspect}'. "\
                           "Cannot use '#{cmd.key}' for now. "\
                           "internal context [IN] is not ready yet"
        else
          @in_context.execute(cmd.value)
        end
      when "exec_out"
        @out_context.execute(cmd.value)
      else
        Kameleon.ui.warn "Unknow command : #{cmd.key}"
      end
    end

    def rescue_exec_error(cmd)
      Kameleon.ui.error "Error executing command : #{cmd.string_cmd}"
      msg = "Press [r] to retry, [c] to continue with execution,"\
            "[a] to abort execution"
      msg = "#{msg}, [o] to switch to local context shell" unless @out_context.nil?
      msg = "#{msg}, [i] to switch to build context shell" unless @in_context.nil?
      responses = ["r","c","a"]
      responses.push("o") unless @out_context.nil?
      responses.push("i") unless @in_context.nil?
      while true
        Kameleon.ui.confirm msg
        answer = $stdin.gets.strip
        $stdout.flush
        if responses.include?(answer)
          return answer unless ["o", "i"].include?(answer)
          if answer.eql? "o"
            @out_context.start_shell
          else
            @in_context.start_shell
          end
          Kameleon.ui.confirm "Getting back to Kameleon ..."
        end
      end
    end

    def do_clean(section_name, fail_silent=false)
      unless @cleaned_sections.include?(section_name)
        begin
          Kameleon.ui.confirm "Cleaning #{section_name}"
          @recipe.sections.clean.fetch(section_name).each do |cmd|
            begin
              exec_cmd(cmd)
            rescue Exception => e
              raise e if not fail_silent
              Kameleon.ui.warn "An error occurred while executing : #{cmd.value}"
            end
          end
        ensure
          @cleaned_sections.push(section_name)
        end
      end
    end

    def do_bootstrap
      Kameleon.ui.confirm "Building external context [OUT]"
      @out_context = Context.new("OUT",
                                 @recipe.global["out_context"]["cmd"],
                                 @recipe.global["out_context"]["workdir"],
                                 @recipe.global["out_context"]["exec_prefix"],
                                 @cwd)
      do_steps("bootstrap")
      do_clean("bootstrap")
    end

    def do_setup
      Kameleon.ui.confirm "Building internal context [IN]"
      @in_context = Context.new("IN",
                                @recipe.global["in_context"]["cmd"],
                                @recipe.global["in_context"]["workdir"],
                                @recipe.global["in_context"]["exec_prefix"],
                                @cwd)
      do_steps("setup")
      do_clean("setup")
    end

    def do_export
      do_steps("export")
      do_clean("export")
    end

    def build
      start_time = Time.now.to_i
      begin
        FileUtils.mkdir_p @cwd
      rescue
        raise BuildError, "Failed to create working directory #{@cwd}"
      end
      @local_context = LocalContext.new("local", @cwd)
      check_requirements
      begin
        do_bootstrap
        do_setup
        do_export
      rescue SystemExit, Interrupt, Exception => e
        Kameleon.ui.warn "Waiting for cleanup before exiting..."
        try_clean_all
        raise e
      else
        total_time = Time.now.to_i - start_time
        Kameleon.ui.confirm("Build total duration : #{total_time} secs")
      end
    end

    def try_clean_all
      ["bootstrap", "setup", "export"].each do |section_name|
        do_clean(section_name, true)
      end
      begin
        @out_context.close! unless @out_context.nil?
        @in_context.close! unless @in_context.nil?
        @local.close! unless @local.nil?
      rescue Errno::EPIPE, Exception
      end
    end

    def check_requirements
      requires = @recipe.global["requirements"]
      Kameleon.ui.confirm "Checking recipe requirements : #{requires.join ' '}"
      missings = requires.map { |cmd| cmd unless @local_context.check_cmd(cmd)}
      missings.compact!
      fail BuildError, "Missing recipe requirements : #{missings.join ' '}" \
           unless missings.empty?
    end

  end

end
