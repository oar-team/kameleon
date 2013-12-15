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
    def initialize(name, required_cmds, exec_cmd=nil)
      @stdout = Kameleon.ui.stdout
      @stderr = Kameleon.ui.stderr
      @name = name
      @exec_cmd = exec_cmd
      @shell = Shell.new @exec_cmd
      @required_cmds = required_cmds
      Kameleon.ui.debug "Initialize context (#{self})"
      instance_variables.each { |v| Kameleon.ui.debug " #{v} = #{instance_variable_get(v)}" }
      @required_cmds.each { |cmd| exec(cmd) }
    rescue Errno::EPIPE, ExecError
      msg = "Error occured when initializing #{name} context. "
      unless exec_cmd.nil?
        msg = "#{msg} Check 'exec_cmd' value in the recipe"
      end
      raise ContextError, msg
    end

    def exec(cmd)
      Kameleon.ui.debug "Running on #{@name} context : #{cmd.inspect}"
      stdout, stderr = @shell.execute(cmd, :stdout => @stdout, :stderr => @stderr)
      Kameleon.ui.debug " exit status : #{@shell.exit_status}\n" \
                        " stdout : #{stdout}\n stderr: #{stderr}"
      fail ExecError, self unless @shell.exit_status.eql? 0
    end

    def start_interactive
      # Create a new subprocess that will just exec the requested program.
      pid = fork { Kernel.exec(@context_cmd) }
      # wait for the child to exit.
      _, status = Process.waitpid2(pid)
      status.success?
    end
  end
end
