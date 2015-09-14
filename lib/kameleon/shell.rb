require 'kameleon/utils'
require 'shellwords'


module Kameleon
  class Shell
    ECHO_CMD = "echo"
    READ_CHUNK_SIZE = 1048576
    EXIT_TIMEOUT = 60

    attr :exit_status
    attr :process
    attr :shell_cmd

    def initialize(context)
      @cmd = context.cmd.chomp
      @context_name = context.name
      @local_workdir = context.local_workdir
      @shell_workdir = context.workdir
      @proxy_cache = context.proxy_cache
      @env_files = context.env_files
      @bash_scripts_dir = File.join("kameleon_scripts", @context_name)
      @bashrc_file = File.join(@bash_scripts_dir, "bash_rc")
      @bash_history_file = File.join(@bash_scripts_dir, "bash_history")
      @bash_env_file = File.join(@bash_scripts_dir, "bash_env")
      @bash_status_file = File.join(@bash_scripts_dir, "bash_status")
      @default_bashrc_file = File.join(Kameleon.source_root, "contrib", "kameleon_bashrc.sh")
      @cmd_tpl = ERB.new(File.read(File.join(Kameleon.source_root,
                                                     "contrib",
                                                     "kameleon_exec_cmd.sh")))
      @cmd_wrapper_tpl = ERB.new(File.read(File.join(Kameleon.source_root,
                                                     "contrib",
                                                     "kameleon_exec_cmd_wrapper.sh")))

      if @shell_workdir
        @bash_scripts_dir = File.join(@shell_workdir, @bash_scripts_dir)
        @bashrc_file = File.join(@shell_workdir, @bashrc_file)
        @bash_history_file = File.join(@shell_workdir, @bash_history_file)
        @bash_env_file = File.join(@shell_workdir, @bash_env_file)
        @bash_status_file = File.join(@shell_workdir, @bash_status_file)
      end

      ## Changing the default bashrc if the cache is activated
      @cache = Kameleon::Persistent_cache.instance

      @shell_cmd = "source #{@default_bashrc_file} 2> /dev/null; "\
                   "#{@cmd} --rcfile #{@bashrc_file}"
      Kameleon.ui.debug("Initialize shell (#{self})")
      # Injecting all variables of the options and assign the variables
      instance_variables.each do |v|
        Kameleon.ui.debug("  #{v} = #{instance_variable_get(v)}")
      end
    end

    def start
      @sent_first_cmd = false
      @process, @stdout, @stderr = fork("pipe")
    end

    def stop
      unless @process.nil?
        @process.stop(0)
        @process = nil
      end
    end

    def started?
      return !@process.nil?
    end

    def exited?
      return !@process.nil? && @process.exited?
    end

    def restart
      stop
      start
    end

    def send_file(source_path, remote_dest_path, chunk_size=READ_CHUNK_SIZE)
      copy_process, = fork("pipe")
      copy_process.io.stdin << init_shell_cmd
      copy_process.io.stdin << "cat > #{remote_dest_path}\n"
      copy_process.io.stdin.flush
      open(source_path, "rb") do |f|
        begin
          copy_process.io.stdin << f.read(chunk_size)
        end until f.eof?
      end
      copy_process.io.stdin.flush
      copy_process.io.stdin.close
      copy_process.wait
      copy_process.poll_for_exit(EXIT_TIMEOUT)
    end

    def init_shell_cmd
      ## log shell error message
      error = read_io(@stderr)
      init_stdout = read_io(@stdout)
      Kameleon.ui.error(error) unless error.empty?
      Kameleon.ui.info(init_stdout) unless init_stdout.empty?
      bashrc_content = ""
      if File.file?(@default_bashrc_file)
        tpl = ERB.new(File.read(@default_bashrc_file))
        bashrc_content = tpl.result(binding)
        if @cache.activated? then
          if @proxy_cache.nil? then
            Kameleon.ui.warn("Variable 'proxy_cache' not defined for this context, persistent cache will not be generated")
          else
            tpl = ERB.new(File.read(@cache.polipo_env))
            bashrc_content << "\n" + ERB.new(File.read(@cache.polipo_env)).result(binding)
          end
        end
      end
      # Inject sigint handler
      bashrc_content << <<-SCRIPT
function save_state_handler {
  echo "Saved ENV in #{@bash_env_file} file"
  (comm -3 <(declare | sort) <(declare -f | sort)) > #{@bash_env_file}
}
trap save_state_handler EXIT
SCRIPT
      bashrc = Shellwords.escape(bashrc_content)
      if @shell_workdir
        unless @shell_workdir.eql? "/"
          change_dir_cmd = "mkdir -p #{@shell_workdir} &&"
        end
        change_dir_cmd = "#{change_dir_cmd} cd #{@shell_workdir}"
        change_dir_cmd = Shellwords.escape(change_dir_cmd)
      end
      shell_cmd = "mkdir -p $(dirname #{@bashrc_file})\n"
      shell_cmd << "rm $(dirname #{@bashrc_file})/*\n"
      shell_cmd << "echo #{bashrc} > #{@bashrc_file}\n"
      unless change_dir_cmd.nil?
        shell_cmd << "echo #{change_dir_cmd} >> #{@bashrc_file}\n"
      end
      shell_cmd << "export KAMELEON_WORKDIR=$PWD\n"
      @env_files.each do |env_file|
        resolved_erb = "\n" + ERB.new(File.read(env_file)).result(binding)
        env_content = <<-SCRIPT
#====================================================
# Begin content of user script '#{env_file.basename}'
#====================================================
#{resolved_erb}
#====================================================
# End content of user script '#{env_file.basename}'
#====================================================
SCRIPT
        env_escaped_content = Shellwords.escape(env_content)
        shell_cmd << "echo #{env_escaped_content} >> #{@bashrc_file}\n"
      end
      shell_cmd << "source #{@bashrc_file}\n"
      shell_cmd << "(comm -3 <(declare | sort) <(declare -f | sort)) > #{@bash_env_file}\n"
      shell_cmd
    end

    def send_command cmd
      shell_cmd = ""
      unless @sent_first_cmd
        shell_cmd << init_shell_cmd
        @sent_first_cmd = true
      end
      cmd_content = Shellwords.escape(@cmd_tpl.result(binding))
      cmd_wrapper_content = Shellwords.escape(@cmd_wrapper_tpl.result(binding))
      shell_cmd << "mkdir -p $(dirname #{File.join(@bash_scripts_dir, "#{cmd}.sh" )})\n"
      shell_cmd << "echo #{cmd_content} > #{File.join(@bash_scripts_dir, "#{cmd}.sh" )}\n"
      shell_cmd << "echo #{cmd_wrapper_content} > #{File.join(@bash_scripts_dir, "#{cmd}_wrapper.sh" )}\n"
      shell_cmd << "bash #{File.join(@bash_scripts_dir, "#{cmd}_wrapper.sh" )}\n"
      @process.io.stdin.puts shell_cmd
      @process.io.stdin.flush
    end

    def execute(cmd, kwargs = {})
      cmd_obj = Command.new(cmd)
      send_command cmd_obj = Command.new(cmd)
      iodata = {:stderr => { :io        => @stderr,
                             :name      => 'stderr',
                             :begin     => false,
                             :end       => false,
                             :begin_pat => cmd_obj.begin_err_pat,
                             :end_pat   => cmd_obj.end_err_pat,
                             :redirect  => kwargs[:stderr],
                             :yield     => lambda{|buf| yield(nil, buf)} },
                :stdout => { :io        => @stdout,
                             :name      => 'stdout',
                             :begin     => false,
                             :end       => false,
                             :begin_pat => cmd_obj.begin_out_pat,
                             :end_pat   => cmd_obj.end_out_pat,
                             :redirect  => kwargs[:stdout],
                             :yield     => lambda{|buf| yield(buf, nil)} }
                }
      while true
        if @process.exited?
          raise ShellExited, "Process '#{@cmd}' exited..."
        end
        iodata.each do |_, iodat|
          if iodat[:end] and not iodat[:begin]
            if @process.exited?
              raise ShellExited, "Process '#{@cmd}' exited..."
            end
            raise ShellError, "Cannot read #{iodat[:begin]} from shell"
          end
        end
        if iodata.all? { |k, iodat| iodat[:end] and iodat[:begin]}
          break
        end
        readers = (iodata.map { |_, v| v[:io] unless v[:end] })
        ready = IO.select(readers.compact, nil, nil, 0.1)
        ready ||= [[]]
        readers = ready[0]
        # Check the readers to see if they're ready
        if readers && !readers.empty?
          readers.each do |r|
            # Read from the IO object
            iodat = r == @stdout ? iodata[:stdout] : iodata[:stderr]
            data = read_io(r)
            # We don't need to do anything if the data is empty
            next if data.empty?
            if !iodat[:begin] && (m = iodat[:begin_pat].match(data))
                iodat[:begin] = true
                data = m[1]
            end
            next unless iodat[:begin] and not iodat[:end]  # ignore chaff
            if !iodat[:end] && (m = iodat[:end_pat].match(data))
              iodat[:end] = true
              data = m[1]
            end
            next if data.empty?
            if iodat[:redirect]
              iodat[:redirect] << data
            else
              iodat[:yield].call data if block_given?
            end
          end
        end
      end
      if @process.exited?
        raise ShellExited, "Process '#{@cmd}' exited..."
      end
      iodata = nil
      return get_status
    end

    def fork_and_wait
      process, _, _ = fork("inherit")
      process.wait()
    end

    protected

    def get_status
      var_name = "__exit_status__"
      @process.io.stdin << "#{ ECHO_CMD } \"#{ var_name }=$(cat #{@bash_status_file})\"\n"
      @process.io.stdin.flush
      while((line = @stdout.gets))
        if (m = %r/#{ var_name }\s*=\s*(.*)/.match line)
          exit_status = m[1]
          unless exit_status =~ /^\s*\d+\s*$/o
            raise ShellError, "could not determine exit status from <#{ exit_status.inspect }>"
          end
          @exit_status = Integer exit_status
          return @exit_status
        end
      end
    end

    def read_io(io)
      data = ""
      while true
        begin
        # Do a simple non-blocking read on the IO object
        data << io.read_nonblock(READ_CHUNK_SIZE)
        rescue Exception => e
          breakable = false
          if e.is_a?(EOFError)
            # An `EOFError` means this IO object is done!
            breakable = true
          elsif defined?(IO::WaitReadable) && e.is_a?(IO::WaitReadable)
            breakable = true
          elsif e.is_a?(Errno::EAGAIN)
            breakable = true
          end
          break if breakable
          raise
        end
      end
      data
    end

    def fork(io)
      command = ["bash", "-c", @shell_cmd]
      Kameleon.ui.info("Starting process: #{@cmd.inspect}")
      Kameleon.ui.debug("Starting shell process: #{ command.inspect}")
      ChildProcess.posix_spawn = true
      process = ChildProcess.build(*command)
      # Create the pipes so we can read the output in real time as
      # we execute the command.
      if io.eql? "pipe"
        stdout, stdout_writer = IO.pipe
        stderr, stderr_writer = IO.pipe
        process.io.stdout = stdout_writer
        process.io.stderr = stderr_writer
        # sets up pipe so process.io.stdin will be available after .start
        process.duplex = true
      elsif io.eql? "inherit"
        process.io.inherit!
      end

      # Start the process
      begin
        process.cwd = @local_workdir
        process.start
        # Wait to child starting
        sleep(0.2)
      rescue ChildProcess::LaunchError => e
        # Raise our own version of the error
        raise ShellError, "Cannot launch #{command.inspect}: #{e.message}"
      end
      if io.eql? "pipe"
        # Make sure the stdin does not buffer
        process.io.stdin.sync = true
        stdout_writer.close()
        stderr_writer.close()
        return process, stdout, stderr
      else
        return process, $stdout, $stderr
      end
    end

    class Command
      class << self
        def counter; @counter ||= 0; end
        def counter= n; @counter = n; end
      end
      attr :value
      attr :number
      attr :id
      attr :slug
      attr :begin_out
      attr :begin_out_pat
      attr :end_out
      attr :end_out_pat
      attr :begin_err
      attr :begin_err_pat
      attr :end_err
      attr :end_err_pat

      def initialize(raw)
        @value = raw.to_s.strip
        @number = self.class.counter
        @slug = Kameleon::Utils.generate_slug(@value)[0...30]
        @id = "%d_%d_%d" % [@number, $$, rand(Time.now.usec)]
        @begin_out = "__CMD_OUT_%s_BEGIN__" % @id
        @end_out = "__CMD_OUT_%s_END__" % @id
        @begin_out_pat = %r/#{ Regexp.escape(@begin_out) }(.*)/m
        @end_out_pat = %r/(.*)#{ Regexp.escape(@end_out) }/m
        @begin_err = "__CMD_ERR_%s_BEGIN__" % @id
        @end_err = "__CMD_ERR_%s_END__" % @id
        @begin_err_pat = %r/#{ Regexp.escape(@begin_err) }(.*)/m
        @end_err_pat = %r/(.*)#{ Regexp.escape(@end_err) }/m
        self.class.counter += 1
      end

      def to_s
        "%05d_#{@slug}" % @number
      end
    end

  end
end
