require 'kameleon/utils'


module Kameleon
  class Shell
    DEFAULT_SHELL_PROG    = 'bash'
    ECHO_CMD = "echo"
    READ_CHUNK_SIZE = 1048576
    EXIT_TIMEOUT = 60

    class Command
      class << self
        def counter; @counter ||= 0; end
        def counter= n; @counter = n; end
      end
      attr :value
      attr :number
      attr :id
      attr :slug
      attr :out,true
      attr :err,true
      attr :begin_out
      attr :begin_out_pat
      attr :end_out
      attr :end_out_pat
      attr :begin_err
      attr :begin_err_pat
      attr :end_err
      attr :end_err_pat

      def initialize(raw)
        @value = raw.to_s
        @number = self.class.counter
        @slug = Kameleon::Utils.generate_slug(@value)[0...30]
        @id = "%d_%d_%d" % [$$, @number, rand(Time.now.usec)]
        @err = ''
        @out = ''
        @begin_out = "__CMD_OUT_%s_BEGIN__" % @id
        @end_out = "__CMD_OUT_%s_END__" % @id
        @begin_out_pat = %r/#{ Regexp.escape(@begin_out) }(.*)/
        @end_out_pat = %r/(.*)#{ Regexp.escape(@end_out) }/
        @begin_err = "__CMD_ERR_%s_BEGIN__" % @id
        @end_err = "__CMD_ERR_%s_END__" % @id
        @begin_err_pat = %r/#{ Regexp.escape(@begin_err) }(.*)/
        @end_err_pat = %r/(.*)#{ Regexp.escape(@end_err) }/
        self.class.counter += 1
      end
    end

    attr :exit_status

    def initialize(cmd, cwd)
      @shell_cmd = [DEFAULT_SHELL_PROG, "-c", "#{cmd}"]
      @cwd = cwd
      @history = []
      start
    end

    def fork(io)
      # @logger.info("Starting process: #{@shell_cmd.inspect}")
      ChildProcess.posix_spawn = true
      process = ChildProcess.build(*@shell_cmd)
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
      process.cwd = @cwd
      process.start

      if io.eql? "pipe"
        # Make sure the stdin does not buffer
        process.io.stdin.sync = true
        stdout_writer.close()
        stderr_writer.close()
        return process, stdout, stderr
      else
        return process
      end
    end

    def start
      # @logger.info("Starting process: #{@shell_cmd.inspect}")
      @process, @stdout, @stderr = fork("pipe")
    end

    def stop
      @process.stop unless @process.nil?
    end

    def restart
      stop
      start
    end

    def send_file(source_path, remote_dest_path, chunk_size=READ_CHUNK_SIZE)
      copy_process, = fork("pipe")
      copy_process.io.stdin << "> #{remote_dest_path}\n"
      copy_process.io.stdin << "cat >> #{remote_dest_path}\n"
      copy_process.io.stdin.flush
      open(source_path, "rb") do |f|
        f_size = f.size
        remaining = f_size
        begin
          copy_process.io.stdin << f.read(chunk_size)
          remaining -= chunk_size
          remaining = 0 if remaining < 0
          percentage = Integer((((f_size - remaining) * 1.0) / f_size) * 100)
          yield percentage if block_given?
        end until f.eof?
      end
      copy_process.io.stdin.flush
      copy_process.io.stdin.close
      copy_process.wait
      copy_process.poll_for_exit(EXIT_TIMEOUT)
    end

    def send_command cmd
      shell_cmd = "#{ ECHO_CMD } -n #{ cmd.begin_err } 1>&2 ;\n"
      shell_cmd << "#{ ECHO_CMD } -n #{ cmd.begin_out }\n"
      shell_cmd << "#{ cmd.value } ;\nexport __exit_status__=$? ;\n"
      shell_cmd << "#{ ECHO_CMD } -n #{ cmd.end_err } 1>&2\n"
      shell_cmd << "#{ ECHO_CMD } -n #{ cmd.end_out }\n"
      @process.io.stdin << shell_cmd
      @process.io.stdin.flush
    end

    def execute(cmd, kwargs = {})
      @history.push(cmd) unless kwargs[:skip_history]
      cmd_obj = Command.new(cmd)
      send_command cmd_obj = Command.new(cmd)
      iodata = {:stderr => { :io        => @stderr,
                             :cmd_io    => cmd_obj.err,
                             :name      => 'stderr',
                             :begin     => false,
                             :end       => false,
                             :begin_pat => cmd_obj.begin_err_pat,
                             :end_pat   => cmd_obj.end_err_pat,
                             :redirect  => kwargs[:stderr],
                             :yield     => lambda{|buf| yield(nil, buf)} },
                :stdout => { :io        => @stdout,
                             :cmd_io    => cmd_obj.out,
                             :name      => 'stdout',
                             :begin     => false,
                             :end       => false,
                             :begin_pat => cmd_obj.begin_out_pat,
                             :end_pat   => cmd_obj.end_out_pat,
                             :redirect  => kwargs[:stdout],
                             :yield     => lambda{|buf| yield(buf, nil)} }
                }
      while true
        iodata.each do |_, iodat|
          raise ExecError, iodat[:name] if iodat[:end] and not iodat[:begin]
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
            if (m = iodat[:end_pat].match(data))
              iodat[:end] = true
              data = m[1]
            end
            if (m = iodat[:begin_pat].match(data))
                iodat[:begin] = true
                data = m[1]
            end
            next unless iodat[:begin] and not iodat[:end]  # ignore chaff
            next if data.empty?
            if iodat[:redirect]
              iodat[:redirect] << data
            else
              iodat[:cmd_io] << data
            end
            iodat[:yield].call data if block_given?
          end
        end
      end
      iodata = nil
      return [get_status, cmd_obj.out, cmd_obj.err]
    end

    protected

    def get_status
      var_name = "__exit_status__"
      puts "#{ ECHO_CMD } \"#{ var_name }=${#{ var_name }}\"\n"
      @process.io.stdin << "#{ ECHO_CMD } \"#{ var_name }=${#{ var_name }}\"\n"
      @process.io.stdin.flush
      while((line = @stdout.gets))
        if (m = %r/#{ var_name }\s*=\s*(.*)/.match line)
          exit_status = m[1]
          unless exit_status =~ /^\s*\d+\s*$/o
            raise ExecError, "could not determine exit status from " \
                             "<#{ exit_status.inspect }>"
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

    def close
      stop
    end
  end
end
