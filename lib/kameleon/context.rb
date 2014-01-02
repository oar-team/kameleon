require 'kameleon/shell'

module Kameleon
  class Context
    def initialize(name, cmd, workdir, exec_prefix, local_workdir)
      @logger = Log4r::Logger.new("kameleon::#{name.downcase}_ctx")
      @cmd = cmd
      @name = name
      @workdir = workdir
      @exec_prefix = exec_prefix
      @local_workdir = local_workdir
      @shell = Kameleon::Shell.new(@cmd, @workdir, @local_workdir)

      @logger.debug("Initialize new context (#{name})")

      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end
    rescue ShellError => e
      raise ContextError, "Error occured when initializing '#{name}_context'."
                          "\n#{e}"
    end

    def execute(cmd)
      cmd_with_prefix = "#{@exec_prefix} #{cmd}"
      @logger.debug("Executing : #{cmd_with_prefix}")
      @shell.execute(cmd_with_prefix) do |out, err|
        @logger.info out.chomp("\n") unless out.nil?
        @logger.error err.chomp("\n") unless err.nil?
      end
      @logger.debug("exit status : #{@shell.exit_status}")
      fail ExecError unless @shell.get_status.eql? 0
    end

    def start_shell
      #TODO: Load env and history
      @logger.info("Starting interactive shell")
      @shell.fork_and_wait
    end

    def closed?
      @shell.exited?
    end

    def close!
      @shell.stop
    end

    def reopen
      @shell.restart
    end

    def check_cmd(cmd)
      @logger.debug("check cmd #{cmd}")
      shell_cmd = "command -v #{cmd} >/dev/null 2>&1"
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
