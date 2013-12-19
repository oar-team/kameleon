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

    def initialize(name, context_cmd)
      @stdout = Kameleon.ui.stdout
      @stderr = Kameleon.ui.stderr
      @name = name
      @context_cmd = context_cmd
      @shell = Shell.new @context_cmd
      Kameleon.ui.debug "Initialize context (#{self})"
      instance_variables.each do |v|
        Kameleon.ui.debug " #{v} = #{instance_variable_get(v)}"
      end
    rescue Errno::EPIPE
      raise ContextError, "Error occured when initializing #{name} context. " \
                          "Check '#{@name}_context' value in the recipe"
    end

    def exec(cmd)
      Kameleon.ui.debug "[#{@name}_context] Executing : #{cmd}"
      @shell.execute(cmd, :stdout => @stdout, :stderr => @stderr)
      Kameleon.ui.debug " exit status : #{@shell.exit_status}"
      fail ExecError unless @shell.exit_status.eql? 0
    end

    def start_shell
      #TODO: Load env and history
      Kameleon.ui.confirm "[#{@name}_context] Starting interactive shell"
      # Create a new subprocess that will just exec the requested program.
      pid = fork { Kernel.exec(@context_cmd) }
      # wait for the child to exit.
      _, status = Process.waitpid2(pid)
      status.success?
    end
  end

  class LocalContext < Context
    def initialize
      super("local", "bash")
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
