require 'kameleon/engine'
require 'log4r'

module Kameleon
  class UI

    def self.main
      @options = {
        :include_paths => []
      }

      option_parser = OptionParser.new do |opts|
        opts.banner = <<BANNER
Kameleon
* Description:
  Kameleon is an Open Source Bash automation tool. It aims at easily generate
  operating system images and export them in any raw or virtual disk format
* Usage:
  kameleon [-i data_path] recipe[.yaml]
* Options:
BANNER
        opts.on("-i", "--include [PATH]", "Include the given path in the kameleon search path") do |i|
          @options[:include_paths].push(File.expand_path(i))
        end

        opts.on("-h","--help", "Show this message.") do
          puts opts
          exit(0)
        end

        opts.on("-o","--output [FILE]",String,"Where to save the image" ) do |o|
           @options[:output_path].push(File.expand_path(o))
        end

        opts.on("-c","--cache [PATH]","Generate cache for the image created") do |path|
          @options[:cache] = path || ""
        end

        opts.on("--from_cache [FILE]","Using specific cache to create the image") do |cache_file|
          @options[:path_to_cache] = cache_file
        end

        opts.on("--make_ckp [STEP]",String,"Checkpoint given step") do |step|
          @options[:make_ckp] = step
          if step.nil?
            puts "There is no argument for option --make_ckp"
            exit(0)
          end
        end

        opts.on("--restart_from_ckp [STEP]",String,"Restart the process form a checkpoint file and a given step") do |step|
          @options[:restart_from_ckp] = step
          if step.nil?
            puts "There is no argument for option --restart_from_ckp"
            exit(0)
          end
        end

        opts.on("-v","--version", "Show this message.") do
          puts "Kameleon #{Kameleon::VERSION}"
          exit 0
        end

      end

      if ARGV.length < 1
        puts option_parser
        exit(1)
      end
      # TODO: use FileOutputter

      # Set logger level for kameleon logger namespace
      logger = Log4r::Logger.new("kameleon")
      logger.outputters = Log4r::Outputter.stderr
      logger.level = Log4r::DEBUG
      # remove unsed logger
      logger = nil

      option_parser.parse!
      engine = Kameleon::Engine.new(@options)
      engine.run()
      @options[:recipe_query] = ARGV[0]
    end
  end
end
