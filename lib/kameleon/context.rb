require 'kameleon/shell'

module Kameleon
  class Context

    attr_accessor :shell
    attr_accessor :name

    def initialize(name, cmd, workdir, exec_prefix, local_workdir, kwargs = {})
      @name = name.downcase
      @cmd = cmd
      @workdir = workdir
      @exec_prefix = exec_prefix
      @local_workdir = local_workdir
      @shell = Kameleon::Shell.new(@name, @cmd, @workdir, @local_workdir, :proxy_cache => kwargs[:proxy_cache])
      Kameleon.ui.debug("Initialize new ctx (#{name})")

      instance_variables.each do |v|
        Kameleon.ui.debug("  #{v} = #{instance_variable_get(v)}")
      end

      @cache = Kameleon::Persistent_cache.instance
    end

    def do_log(out, log_level)
      prefix = "[#{@name}] "
      out.gsub!("\r", "\r#{prefix}")
      if out.end_with?("\n")
        out.split( /\r?\n/ ).each {|m| log(log_level, prefix + m) }
      else
        if out.match("\n")
          out_lines = out[ /\A.*\n/m ]
          out_lines.split( /\r?\n/ ).each {|m| log(log_level, prefix + m) }
          out.slice! out_lines
          log_progress(log_level, prefix + out)
          Kameleon.log_on_progress = true
        end
        if Kameleon.log_on_progress
          log_progress(log_level, out)
        else
          log_progress(log_level, prefix + out)
          Kameleon.log_on_progress = true
        end
      end
    end

    def log(log_level, msg)
      Kameleon.ui.confirm(msg) if log_level == "info"
      Kameleon.ui.error(msg) if log_level == "error"
      Kameleon.ui.debug msg if log_level == "debug"
    end

    def log_progress(log_level, msg)
      Kameleon.ui.confirm(msg, false) if log_level == "info"
      Kameleon.ui.error(msg, false) if log_level == "error"
      Kameleon.ui.debug msg if log_level == "debug"
    end

    def execute(cmd, kwargs = {})
      lazyload_shell
      cmd_with_prefix = "#{@exec_prefix} #{cmd}"
      cmd_with_prefix.split( /\r?\n/ ).each {|m| Kameleon.ui.debug "+ #{m}" }
      log_level = kwargs.fetch(:log_level, "info")
      exit_status = @shell.execute(cmd_with_prefix, kwargs) do |out, err|
        do_log(out, log_level) unless out.nil?
        do_log(err, "error") unless err.nil?
      end
      Kameleon.ui.debug("Exit status : #{exit_status}")
      fail ExecError unless exit_status.eql? 0
    rescue ShellError, Errno::EPIPE  => e
      Kameleon.ui.debug("Shell cmd failed to launch: #{@shell.shell_cmd}")
      raise ShellError, e.message + ". Check the cmd argument of the '#{@name}_context'."
    end

    def pipe(cmd, other_cmd, other_ctx)
      if @cache.mode == :from then
        Kameleon.ui.info("Redirecting pipe into cache")
        tmp = @cache.get_cache_cmd(cmd)
      else
        tmp = Tempfile.new("pipe-#{ Kameleon::Utils.generate_slug(cmd)[0..20] }")
        Kameleon.ui.debug("Running piped commands")
        Kameleon.ui.debug("Saving STDOUT from #{@name}_ctx to local file #{tmp.path}")
        execute(cmd, :stdout => tmp)
        tmp.close
      end
      ## Saving one side of the pipe into the cache
      if @cache.mode == :build then
        @cache.cache_cmd(cmd,tmp.path)
      end

      Kameleon.ui.debug("Forwarding #{tmp.path} to STDIN of #{other_ctx.name}_ctx")
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
      Kameleon.ui.info("Starting interactive shell")
      @shell.fork_and_wait
    rescue ShellError => e
      e.message.split( /\r?\n/ ).each {|m| Kameleon.ui.error m }
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
