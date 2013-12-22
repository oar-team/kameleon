module Kameleon
  class Context
    class Shell < Session::Bash
      def initialize(exec_cmd)
        unless exec_cmd.nil?
          self.class::default_prog=exec_cmd
        end
        super()
      end
    end

    def initialize(name, context_cmd, workdir)
      @workdir = workdir
      @name = name
      @safe_context_cmd = "sh -c 'cd #{@workdir} && #{context_cmd}'"
      @shell = Shell.new @safe_context_cmd
      @stdout = Kameleon.ui.stdout
      @stderr = Kameleon.ui.stderr
      Kameleon.ui.debug "Initialize new context (#{name})"
      instance_variables.each do |v|
        Kameleon.ui.debug " #{v} = #{instance_variable_get(v)}"
      end
    rescue Errno::EPIPE
      raise ContextError, "Error occured when initializing #{name} context. " \
                          "Check '#{@name}_context' value in the recipe"
    end

    def exec(cmd)
      Kameleon.ui.confirm "[#{@name}] #{cmd}"
      @shell.execute(cmd, :stdout => @stdout, :stderr => @stderr)
      Kameleon.ui.debug " exit status : #{@shell.exit_status}"
      fail ExecError unless @shell.exit_status.eql? 0
    end

    def start_shell
      #TODO: Load env and history
      Kameleon.ui.confirm "[#{@name}] Starting interactive shell"
      system(@safe_context_cmd)
    end

    def check_cmd(cmd)
      shell_cmd = "command -v #{cmd} >/dev/null 2>&1|| bash -c 'exit 1'"
      exec(shell_cmd)
      true
    rescue ExecError
      false
    end
  end
end
