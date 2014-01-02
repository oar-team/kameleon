require 'kameleon/utils'


module Kameleon
  class Shell < Session::Bash
    EXIT_TIMEOUT = 60

    def initialize(cmd, shell_workdir, local_workdir, kwargs = {})
      @logger = Log4r::Logger.new("kameleon::shell")
      @debug = kwargs[:debug].nil? ? false : true
      @cmd = cmd
      @local_workdir = local_workdir
      @shell_workdir = shell_workdir
      @shell_cmd = "#{@cmd} -c 'mkdir -p #{@shell_workdir} && cd #{@shell_workdir} && bash'"
      super("debug" => @debug)
      @logger.debug("Initialize shell (#{self})")
      # Injecting all variables of the options and assign the variables
      instance_variables.each do |v|
        @logger.debug("  #{v} = #{instance_variable_get(v)}")
      end
    end

    def fork_and_wait
      process, = fork("inherit")
      process.wait
    end

    def send_file(source_path, remote_dest_path, chunk_size=READ_CHUNK_SIZE)
      process, = fork("pipe")
      process.io.stdin << "> #{remote_dest_path}\n"
      process.io.stdin << "cat >> #{remote_dest_path}\n"
      process.io.stdin.flush
      open(source_path, "rb") do |f|
        f_size = f.size
        remaining = f_size
        begin
          process.io.stdin << f.read(chunk_size)
          remaining -= chunk_size
          remaining = 0 if remaining < 0
          percentage = Integer((((f_size - remaining) * 1.0) / f_size) * 100)
          yield percentage if block_given?
        end until f.eof?
      end
      process.io.stdin.flush
      process.io.stdin.close
      process.wait
      process.poll_for_exit(EXIT_TIMEOUT)
    end

    def exited?
      @process.exited?
    end

    def stop
      @process.stop
    end

    def restart
      @process.stop unless exited?
      @stdin, @stdout, @stderr = __popen3
    end

    private

    def __popen3(*unused_args)
      @process, stdout, stderr = fork("pipe")
      return [@process.io.stdin, stdout, stderr]
    end

    def send_command cmd
      stdin.printf "%s '%s' 1>&2 ;", ECHO, cmd.begin_err
      stdin.printf "%s '%s' ;", ECHO, cmd.begin_out

      stdin.printf "%s ;", cmd.cmd
      stdin.printf "export __exit_status__=$? ;"

      stdin.printf "%s '%s' 1>&2 ;", ECHO, cmd.end_err
      stdin.printf "%s '%s' \n", ECHO, cmd.end_out

      stdin.flush
    end

    def fork(io)
      @logger.debug("Starting process: #{@shell_cmd.inspect}")
      ChildProcess.posix_spawn = true
      process = ChildProcess.build(*["bash", "-c", @shell_cmd])

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

      # move to workdir
      process.cwd = @cwd
      # # Detach from parent
      # process.detach = true
      process.start

      if io.eql? "pipe"
        stdout_writer.close()
        stderr_writer.close()
        return process, stdout, stderr
      else
        return process, $stdout, $stderr
      end
    end

  end
end
