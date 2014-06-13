require 'childprocess'
require 'singleton'
require 'socket'
module Kameleon
  #This ruby class will control the execution of Polipo web proxy
  class Persistent_cache

    include Singleton
    attr_reader :polipo_env, :cache_dir,:polipo_port
    attr_writer :activated, :cwd, :polipo_path, :cache_path
    attr_accessor :mode, :name, :recipe_files
    def initialize()
      @logger = Log4r::Logger.new("kameleon::[kameleon]")
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

      @mode = nil #It could be build or from
      @cache_dir = ""
      @polipo_path = nil
      @cwd = ""
      #structure {:cmd => "cmd", :stdout_filename => "file_name"}
      @cmd_cached = []
      @cache_path = ""
      @current_cmd_id = nil
      @current_step_dir = nil
      @recipe_files = []
      @cached_recipe_dir = nil
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
      @cache_dir = File.join(@cwd,"/cache/")
    end

    def create_cache_directory(step_name)
      @logger.notice("Creating  cache directory #{step_name} for Polipo")
      directory_name = File.join(@cache_dir,"#{step_name}")
      FileUtils.mkdir_p directory_name
      directory_name
    end

    def start_web_proxy_in(directory)

      ## setting current step dir
      @current_step_dir = directory
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
      return true
    end


    def stop_web_proxy
      @polipo_process.stop
      @logger.notice("Stopping web proxy polipo")
    end

    def pack()
      @logger.notice("Packing up the generated cache in #{@cwd}")
      execute("tar","-cf #{@name}-cache.tar -C cache/ .",@cwd)
      # The cache directory cannot be deleted due to the checkpoints
    end

    def unpack(cache_path)
      @logger.notice("Unpacking persistent cache: #{cache_path}")
      FileUtils.mkdir_p @cache_dir
      execute("tar","-xf #{cache_path} -C #{@cache_dir}")
    end


    # This function caches the command with its respective stdout
    # a command id is associate to a file
    def cache_cmd_id(cmd_identifier)
      @current_cmd_id = cmd_identifier
      return true
    end

    def cache_cmd(cmd,file_path)
      @logger.notice("Caching file")
      @logger.debug("command: cp #{file_path} #{@cwd}/cache/files/")
      FileUtils.mkdir_p @current_step_dir + "/data/"
      FileUtils.cp file_path, @current_step_dir + "/data/"
      @cmd_cached.push({:cmd_id => @current_cmd_id,
                        :cmd => cmd ,
                        :stdout_filename => File.basename(file_path)})
    end

    def get_cache_cmd(cmd)
      return false if @mode == :build
      cache_line = @cmd_cached.select{ |reg|
        (reg[:cmd_id] == @current_cmd_id && reg[:cmd] == cmd) }.first

      return File.new("#{@current_step_dir}/data/#{cache_line[:stdout_filename]}","r")
    end

    def stop()

      @polipo_process.stop
      @logger.notice("Stopping web proxy polipo")
      @logger.notice("Finishing persistent cache with last files")

      if @mode == :build then
        File.open("#{@cache_dir}/cache_cmd_index",'w+') do |f|
          f.puts(@cmd_cached.to_yaml)
        end

        @recipe_files.each do |file|
          ## Getting the recipe path
          recipe_path = nil
          file.ascend do |path|
            if path.to_s.include?("recipe") then
              recipe_path = path
            end
          end
          recipe_dir = file.relative_path_from(recipe_path).dirname.to_s
          FileUtils.mkdir_p @cached_recipe_dir + "/" + recipe_dir
          FileUtils.cp file, @cached_recipe_dir + "/"+ recipe_dir
        end

        ## Saving metadata information
        @logger.notice("Caching recipe")
        File.open("#{@cached_recipe_dir}/header",'w+') do |f|
          f.puts({:name => @name}.to_yaml)
        end

        pack

      end

    end

    def start()

      check_polipo_binary
      if @mode == :from then
        begin
          unpack(@cache_path)
        rescue
          raise BuildError, "Failed to untar the persistent cache file"
        end
        ## We have to load the file
        @cmd_cached = YAML.load(File.read("#{@cache_dir}/cache_cmd_index"))
      end
      @activated = true
      @cached_recipe_dir = @cache_dir + "/recipe"
      FileUtils.mkdir_p @cached_recipe_dir
    end

    def get_recipe()
      cached_recipe=Dir.mktmpdir("cache")
      execute("tar","-xf #{@cache_path} -C #{cached_recipe} ./recipe")
      @logger.notice("Getting cached recipe")
      # This will look for the name of the recipe
      recipe_header = YAML::load(File.read("#{cached_recipe}/recipe/header"))
      @name = recipe_header[:name]
      return "#{cached_recipe}/recipe/#{@name}.yaml"
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

