require 'childprocess'
require 'singleton'
require 'socket'

module Kameleon
  #This ruby class will control the execution of Polipo web proxy
  class Persistent_cache

    include Singleton
    attr_reader :polipo_env, :cache_dir,:polipo_port
    attr_writer :activated, :cwd, :polipo_path, :name
    def initialize()
      @logger = Log4r::Logger.new("kameleon::[Persistent cache]")
      ## we must configure Polipo to be execute for the in and out context
      ## we have to start polipo in the out context for debootstrap step

      @polipo_env = File.join(Kameleon.source_root,
                              "contrib",
                              "polipo_env.sh")

      @polipo_process = nil
      @polipo_port = find_unused_port

      @polipo_cmd_options = {:diskCacheRoot => "",
                            :idleTime => "5",
                            :chunkHighMark => "425165824",
                            :proxyPort => @polipo_port,
                            #:proxyOffline => "true"
                            :relaxTransparency =>"true"
                            }

      @activated = false

      @cache_dir = ""
      @polipo_path = nil
      @cwd = ""

    end

    def find_unused_port
      ports = (8000..9000)
      port = 0
      tmp = nil
      ports.each do |p|
        begin
          port = p
          tmp = TCPServer.new('localhost',port)
        rescue
          port =0
        end
        break if(port>0)
      end
      tmp.close
      port
    end

    def check_polipo_binary


      @polipo_path ||= which("polipo")

      if @polipo_path.nil? then
        @logger.error("Polipo binary not found, make sure it is in your current PATH")
        @logger.error("or use the option --proxy_path")
        raise BuildError, "Failed to use persistent cache"
      end
    end

    def activated?
      @activated
    end


    def cwd=(dir)
      @cwd = dir
      @cache_dir = @cwd + "/cache/"
    end

    def create_cache_directory(step_name)
      @logger.notice("Creating  cache directory #{step_name} for Polipo")
      directory_name = @cache_dir + "/#{step_name}"
      FileUtils.mkdir_p directory_name
      directory_name
    end

    def start_web_proxy_in(directory)
      ## This function assumes that the cache directory has already been created by the engine
      ## Stopping first the previous proxy
      ## have to check if polipo is running
      @logger.notice("Starting web proxy Polipo in directory #{directory} using port: #{@polipo_port}")
      @polipo_process.stop unless @polipo_process.nil?
      command = ["#{@polipo_path}/polipo"]
      @polipo_cmd_options[:diskCacheRoot] = directory
      @polipo_cmd_options.each{ |v,k| command.push("#{v}=#{k}") }
      ChildProcess.posix_spawn = true
      @polipo_process = ChildProcess.build(*command)
      @polipo_process.io.stdout = Tempfile.new("polipo_output")
      @polipo_process.start
    end


    def stop_web_proxy
      @polipo_process.stop
      @logger.notice("Stopping web proxy polipo")
    end

    def pack()
      @logger.notice("Packing up the generated cache in #{@cwd}")
      execute("tar","-cf #{@name}-cache.tar cache/",@cwd)
      # The cache directory cannot be deleted due to the checkpoints
    end

    def unpack(cache_path)
      @logger.notice("Unpacking persistent cache: #{cache_path}")
      execute("tar","-xf #{cache_path} -C #{@cwd}")
    end

    def execute(cmd,args,dir=nil)
      command = [cmd ] + args.split(" ")
#      @logger.notice(" command generated: #{command}")
      process = ChildProcess.build(*command)
      process.cwd = dir unless dir.nil?
      process.start
      process.wait
    end

    def which(cmd)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exe = File.join(path, "#{cmd}")
        return path if File.executable? exe
      end
      return nil
    end


  end

end

