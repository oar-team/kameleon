require 'kameleon/shell'

module Kameleon
  class Context

    attr_accessor :shell, :name

    def initialize(name, cmd, workdir, exec_prefix, local_workdir)
      @name = name.downcase
      @logger = Log4r::Logger.new("kameleon::[#{@name}_ctx]")
      @cmd = cmd
      @workdir = workdir
      @exec_prefix = exec_prefix
      @local_workdir = local_workdir
      @shell = Kameleon::Shell.new(@cmd, @workdir, @local_workdir)
      @logger.debug("Initialize new ctx (#{name})")

      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end
    rescue ShellError => e
      raise ContextError, "Error occured when initializing '#{name}_context'."
                          "\n#{e}"
    end

    def execute(cmd, kwargs = {})
      cmd_with_prefix = "#{@exec_prefix} #{cmd}"
      @logger.debug("Executing : #{cmd_with_prefix}")
      @shell.execute(cmd_with_prefix, kwargs) do |out, err|
        out.split( /\r?\n/ ).each {|m| @logger.info m } unless out.nil?
        err.split( /\r?\n/ ).each {|m| @logger.error m } unless err.nil?
      end
      @logger.debug("exit status : #{@shell.exit_status}")
      fail ExecError unless @shell.get_status.eql? 0
    end

    def pipe(cmd, remote_cmd, remote_context)
      progressbar = ProgressBar.create(:title => "Forwaring pipe",
                                       :total => nil)
      tempfile = Tempfile.new("pipe-#{ Kameleon::Utils.generate_slug(cmd) }")
      execute(cmd, :stdout => tempfile)
      tempfile.close
      progressbar.total = 100

      dest_pipename = "./pipe-#{ Kameleon::Utils.generate_slug(remote_cmd) }"
      # binding.pry
      remote_context.send_file(tempfile.path, dest_pipename) do |p|
        progressbar.progress = p
      end
      progressbar.finish
      remote_cmd_with_pipe = "cat #{dest_pipename} |" \
                             " #{remote_cmd} && rm #{dest_pipename}"
      remote_context.execute(remote_cmd_with_pipe)
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

    def send_file(source_path, dest_path)
      @shell.send_file(source_path, dest_path) do |p|
        yield p
      end
    end
  end

  class LocalContext < Context
    def initialize(name, local_workdir)
      super(name, "bash", local_workdir, "", local_workdir)
    end
  end
end
