require 'kameleon/recipe'
require 'pry'

module Kameleon
  class Macrostep

    class Microstep

      class Command
        attr_accessor :string_cmd
        def initialize(yaml_cmd)
          @string_cmd = YAML.dump(yaml_cmd).gsub("---", "").strip
        end

        def key
          YAML.load(@string_cmd).keys.first
        rescue
          raise RecipeError, "Invalid recipe syntax : '#{@string_cmd.inspect}'"\
                             " must be Array or Hash"
        end

        def value
          object = YAML.load(@string_cmd)
          _, val = object.first
          # Nested commands
          if val.kind_of? Array
            val = val.map { |item| Command.new(item) }
          end
          val
        end
      end

      attr_accessor :commands, :name

      def initialize(hash_microstep)
        @name, cmd_list = hash_microstep.first
        @commands = []
        cmd_list.each { |cmd_hash| @commands.push Command.new(cmd_hash) }
      rescue
        fail RecipeError, "Invalid microstep \"#{name}\": should be one of the "\
                        "defined commands (See documentation)"
      end

      def empty?
        @commands.empty?
      end

      def append(cmd_list)
        cmd_list.each {|cmd| @commands.push cmd}
      end

      def push(cmd)
        @commands.push cmd
      end

      def each(&block)
        @commands.each(&block)
      end

      def map(&block)
        @commands.map(&block)
      end

    end

    attr_accessor :path, :clean, :microsteps, :variables, :name

    def initialize(path, args, recipe)
      @logger = Log4r::Logger.new("kameleon::recipe")
      @recipe = recipe
      @variables = recipe.global.clone
      @microsteps = []
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @clean = Microstep.new({"clean_#{@name}"=> []})
      @init = Microstep.new({"init_#{@name}"=> []})

      yaml_microsteps = YAML.load_file(@path)
      if not yaml_microsteps.kind_of? Array
        fail ReciepeError, "The macrostep #{path} is not valid "
                           "(should be a list of microsteps)"
      end
      yaml_microsteps.each{ |yaml_microstep|
        @microsteps.push Microstep.new(yaml_microstep)
      }

      # look for microstep selection in option
      if args
        selected_microsteps = []
        args.each do |entry|
          if entry.kind_of? String
            selected_microsteps.push entry
          elsif entry.kind_of? Hash
            # resolve variable before using it
            entry.each do |key, value|
              @variables[key] = Utils.resolve_vars(value, @path, @variables)
            end
          end
        end
        if selected_microsteps.nil?
          # Some steps are selected so remove the others
          # WARN: Allow the user to define this list not in the original order
          strip_microsteps = []
          selected_microsteps.each do |microstep_name|
            strip_microsteps.push(find_microstep(microstep_name))
          end
          @microsteps = strip_microsteps
        end
      end
    end

    # :return: the microstep in this macrostep by name
    def find_microstep(microstep_name)
      @logger.info("Looking for macrostep  : #{microstep_name}")
      @microsteps.each do |microstep|
        if microstep_name.eql? microstep.name
          return microstep
        end
      end
      fail RecipeError, "Can't find microstep '#{microstep_name}' "\
                        "in macrostep '#{name}'"
    end

    # Resolve macrosteps variable
    def resolve!()
      #handle clean methods
      def resolve_hooks(cmd)
        if (cmd.key =~ /on_(.*)clean/ || cmd.key =~ /on_(.*)init/)
          if cmd.key.eql? "on_clean"
            @clean.append cmd.value
            return
          elsif cmd.key.eql? "on_init"
            @init.append cmd.value
            return
          else
            Recipe::Section.sections.each do |section|
              if cmd.key.eql? "on_#{section}_clean"
                @recipe.sections.clean[section].append cmd.value
                return
              elsif cmd.key.eql? "on_#{section}_init"
                @recipe.sections.init[section].append cmd.value
                return
              end
            end
          end
          fail RecipeError, "Invalid clean command : '#{cmd.key}'"
        else
          return cmd
        end
      end

      def resolve_check_cmd(cmd)
        if %w(check_cmd_out check_cmd_in).include?(cmd.key)
          section_name = cmd.key.include?("in") ? "setup" : "bootstrap"
          cmd_key = "exec_#{cmd.key.gsub("check_cmd_", "")}"
          names = cmd.value.split(%r{,\s*}).map(&:split).flatten
          names.each do |name|
            shell_cmd = "command -V #{name} ||" \
                        "echo 1>&2 '#{name} is missing' | false"
            @recipe.sections.init[section_name].push({cmd_key => shell_cmd})
          end
          return
        else
          return cmd
        end
      end
      # resolve and strip check_cmd_in/out hooks
      @microsteps.each do |microstep|
        microstep.commands.map! do |cmd|
          cmd.string_cmd = Utils.resolve_vars(cmd.string_cmd, @path, @variables)
          resolve_check_cmd(cmd)
        end
      end
      # resolve and strip other hooks
      @microsteps.each do |microstep|
        microstep.commands.map! do |cmd|
          resolve_hooks(cmd) unless cmd.nil?
        end
      end
      # remove nil values
      @microsteps.each { |microsteps| microsteps.commands.compact! }
    end


    def each(&block)
      @microsteps.each(&block)
    end

    def map(&block)
      @microsteps.map(&block)
    end

    def empty?
      @microsteps.empty?
    end

  end
end
