require 'kameleon/shell'

module Kameleon
  class Context
    def initialize(name, cmd, workdir, exec_prefix, local_workdir)
      @cmd = cmd
      @name = name
      @workdir = workdir
      @exec_prefix = exec_prefix
      @local_workdir = local_workdir
      @shell = Kameleon::Shell.new(@cmd, @local_workdir)
      Kameleon.ui.debug "Initialize new context (#{name})"
      instance_variables.each do |v|
        Kameleon.ui.debug " #{v} = #{instance_variable_get(v)}"
      end
      Kameleon.ui.debug "Checking context (#{name})"
      execute("true")
    # rescue
    #   raise ContextError, "Error occured when initializing #{name} context. " \
    #                       "Check '#{@name}_context' value in the recipe"
    end

    def execute(cmd)
      cmd_with_prefix = "#{@exec_prefix} #{cmd}"
      Kameleon.ui.confirm "[#{@name}] #{cmd_with_prefix}"
      @shell.execute(cmd_with_prefix) do |out, err|
        Kameleon.ui.stdout << out unless out.nil?
        Kameleon.ui.stderr << err unless err.nil?
      end
      Kameleon.ui.debug " exit status : #{@shell.exit_status}"
      fail ExecError unless @shell.exit_status.eql? 0
    end

    def start_shell
      #TODO: Load env and history
      Kameleon.ui.confirm "[#{@name}] Starting interactive shell"
      @shell.fork("inherit").wait
    end

    def check_cmd(cmd)
      shell_cmd = "command -v #{cmd} >/dev/null 2>&1|| bash -c 'exit 1'"
      execute(shell_cmd)
      true
    rescue ExecError
      false
    end
  end
  class LocalContext < Context
    def initialize(name, local_workdir)
      super(name, "bash", local_workdir, "", local_workdir)
    end
  end
end
