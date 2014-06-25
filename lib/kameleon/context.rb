require 'kameleon/shell'

module Kameleon
  class Context

    attr_accessor :shell
    attr_accessor :name

    def initialize(name, cmd, workdir, exec_prefix, local_workdir, kwargs = {})
      @name = name.downcase
      @logger = Log4r::Logger.new("kameleon::[#{@name}_ctx]")
      @cmd = cmd
      @workdir = workdir
      @exec_prefix = exec_prefix
      @local_workdir = local_workdir
      @shell = Kameleon::Shell.new(@name, @cmd, @workdir, @local_workdir, :proxy_cache => kwargs[:proxy_cache])
      @logger.debug("Initialize new ctx (#{name})")
      @log_on_progress = false

      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end

      @cache = Kameleon::Persistent_cache.instance
    end

    def do_log(out, log_level)
      if @log_on_progress
        log_progress(log_level, out)
        @log_on_progress = false if out.match(/\n$/)
      else
        if out.match(/\n$/)
          out.split( /\r?\n/ ).each {|m| log(log_level, m) }
        else
          log_progress(log_level, out)
          @log_on_progress = true
        end
      end
    end

    def log(log_level, msg)
      @logger.info msg if log_level == "info"
      @logger.error msg if log_level == "error"
      @logger.debug msg if log_level == "debug"
    end

    def log_progress(log_level, msg)
      @logger.progress_info msg if log_level == "info"
      @logger.progress_error msg if log_level == "error"
      @logger.debug msg if log_level == "debug"
    end

    def execute(cmd, kwargs = {})
      lazyload_shell
      cmd_with_prefix = "#{@exec_prefix} #{cmd}"
      cmd_with_prefix.split( /\r?\n/ ).each {|m| @logger.debug "+ #{m}" }
      log_level = kwargs.fetch(:log_level, "info")
      exit_status = @shell.execute(cmd_with_prefix, kwargs) do |out, err|
        do_log(out, log_level) unless out.nil?
        do_log(err, "error") unless err.nil?
      end
      @logger.debug("Exit status : #{exit_status}")
      fail ExecError unless exit_status.eql? 0
    rescue ShellError, Errno::EPIPE  => e
      @logger.debug("Shell cmd failed to launch: #{@shell.shell_cmd}")
      raise ShellError, e.message + ". Check the cmd argument of the '#{@name}_context'."
    end

    def pipe(cmd, other_cmd, other_ctx)
      if @cache.mode == :from then
        @logger.info("Redirecting pipe into cache")
        tmp = @cache.get_cache_cmd(cmd)
      else
        tmp = Tempfile.new("pipe-#{ Kameleon::Utils.generate_slug(cmd)[0..20] }")
        @logger.debug("Running piped commands")
        @logger.debug("Saving STDOUT from #{@name}_ctx to local file #{tmp.path}")
        execute(cmd, :stdout => tmp)
        tmp.close
      end
      ## Saving one side of the pipe into the cache
      if @cache.mode == :build then
        @cache.cache_cmd(cmd,tmp.path)
      end

      @logger.debug("Forwarding #{tmp.path} to STDIN of #{other_ctx.name}_ctx")
      dest_pipe_path = "${KAMELEON_WORKDIR}/pipe-#{ Kameleon::Utils.generate_slug(other_cmd)[0..20] }"
      other_ctx.send_file(tmp.path, dest_pipe_path)
      other_cmd_with_pipe = "cat #{dest_pipe_path} | #{other_cmd} && rm #{dest_pipe_path}"
      other_ctx.execute(other_cmd_with_pipe)
    end

    def lazyload_shell()
      unless @shell.started?
        @shell.restart
        execute("echo The '#{name}_context' has been initialized", :log_level => "info")
      end
    rescue
      @shell.stop
      raise
    end

    def start_shell
      #TODO: Load env and history
      lazyload_shell
      @logger.info("Starting interactive shell")
      @shell.fork_and_wait
    rescue ShellError => e
      e.message.split( /\r?\n/ ).each {|m| @logger.error m }
    end

    def closed?
      return !@shell.started? || @shell.exited?
    end

    def close!
      @shell.stop
    end

    def reopen
      @shell.restart
    end

    def send_file(source_path, dest_path)
      @shell.send_file(source_path, dest_path)
    end
  end

end
