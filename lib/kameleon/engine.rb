require 'kameleon/recipe'
require 'kameleon/context'
require 'pry'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @recipe = recipe
      @recipe.resolve!
      @recipe.check_recipe
      @build_context = nil
      @launch_context = nil
      @local_context = LocalContext.new
      @cleaned_sections = []
    end

    def do_steps(section_name)
      unless @recipe.sections.key?(section_name)
        Kameleon.ui.warn "Missing #{section_name} section. Skip"
        return
      end
      Kameleon.ui.confirm "Starting section: #{section_name}"
      @recipe.sections.fetch(section_name).each do |macrostep|
        Kameleon.ui.confirm "Running macrostep: #{macrostep.name}"
        begin
          macrostep.microsteps.each do |microstep|
            Kameleon.ui.confirm "Executing microstep: #{microstep.name}"
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
                  @in_context.exec("true") unless @in_context.nil?
                  @out_context.exec("true") unless @out_context.nil?
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
      context_mapping = { "exec" => @build_context,
                          "exec_local" => @launch_context}
      skipping_alert = lambda {
        context_name = cmd.key == "exec" ? "Build" : "Launch"
        Kameleon.ui.warn "Skipping cmd : #{cmd.string_cmd}. "\
                         "Cannot use '#{cmd.key}' for now. "\
                         "#{context_name} context is not ready yet"
      }

      if context_mapping.keys.include?(cmd.key)
        context = context_mapping.fetch(cmd.key)
        if context.nil?
          skipping_alert.call
        else
          context.exec(cmd.value)
        end
      else
        Kameleon.ui.warn "Unknow command : #{cmd.key}"
      end
    end

    def rescue_exec_error(cmd)
      Kameleon.ui.error "Error executing command : #{cmd.string_cmd}"
      msg = "Press [r] to retry, [c] to continue with execution,"\
            "[a] to abort execution"
      msg = "#{msg}, [s] to switch to launch context shell" unless @launch_context.nil?
      msg = "#{msg}, [b] to switch to build context shell" unless @build_context.nil?
      responses = ["r","c","a"]
      responses.push("s") unless @launch_context.nil?
      responses.push("b") unless @build_context.nil?
      while true
        Kameleon.ui.confirm msg
        answer = $stdin.gets.strip
        $stdout.flush
        if responses.include?(answer)
          return answer unless ["s", "b"].include?(answer)
          @launch_context.start_shell if answer.eql? "s"
          @build_context.start_shell if answer.eql? "s"
          Kameleon.ui.confirm "Getting back to Kameleon ..."
        end
      end
    end

    def do_clean(section_name, fail_silent=false)
      unless @cleaned_sections.include?(section_name)
        begin
          Kameleon.ui.confirm "Cleaning #{section_name}"
          @recipe.sections.clean.fetch(section_name).each do |cmd|
            # begin
              exec_cmd(cmd)
            # rescue Exception => e
            #   raise e if not fail_silent
            #   Kameleon.ui.warn "An error occurred while executing : #{cmd.value}"
            # end
          end
        ensure
          @cleaned_sections.push(section_name)
        end
      end
    end

    def do_bootstrap
      @launch_context = Context.new "launch", @recipe.global["launch_context"]
      do_steps("bootstrap") and do_clean("bootstrap")
    end

    def do_setup
      @build_context = Context.new "build", @recipe.global["build_context"]
      do_steps("setup") and do_clean("setup")
    end

    def do_export
      do_steps("export") and do_clean("export")
    end

    def build
      Kameleon.ui.confirm_title "Starting build"
      check_requirements
      do_bootstrap and do_setup and do_export
    rescue SystemExit, Interrupt, Exception => e
      Kameleon.ui.warn "Waiting for cleanup before exiting..."
      try_clean_all
      raise e
    end

    def try_clean_all
      ["bootstrap", "setup", "export"].each do |section_name|
        do_clean(section_name, true)
      end
      begin
        @launch_context.close! unless @launch_context.nil?
        @build_context.close! unless @build_context.nil?
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
