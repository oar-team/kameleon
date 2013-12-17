require 'kameleon/recipe'

module Kameleon
  class Macrostep

    class Microstep

      class Command
        attr_accessor :key, :val
        def initialize(yaml_cmd)
          @key, @val = yaml_cmd.first
        end
      end

      attr_accessor :commands, :name

      def initialize(yaml_microstep)
        @name, cmd_list = yaml_microstep.first
        @commands = []
        cmd_list.each {|cmd| @commands.push Command.new(cmd)}
      end

    end

    attr_accessor :path

    def initialize(path, args, global_vars)
      @variables = global_vars.clone
      @microsteps = []
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      yaml_microsteps = YAML.load_file(@path)
      if not yaml_microsteps.kind_of? Array
        fail ReciepeError, "The macrostep #{path} is not valid (should be a list of microsteps)"
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
            @variables.merge! entry
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
      @microsteps.each do |microstep|
        if microstep_name.eql? microstep.name
          return microstep
        end
      end
      fail Error ,"Can't find microstep \"#{microstep_name}\" in macrostep \"#{@name}\""
    end

    # Resolve macrosteps variable
    def resolve!()

      def resolve_vars(cmd_string)
        cmd_string.gsub(/\$\$[a-zA-Z0-9\-_]*/) do |variable|
          # remove the dollars
          strip_variable = variable[2,variable.length]

          # check in local vars
          if @variables.has_key? strip_variable
            value = @variables[strip_variable]
          else
            fail RecipeError, "#{@path}: variable #{variable} not found in local or global"
          end
          return $` + resolve_vars(value + $')
        end
      end

      #TODO handle clean methods
      def resolve_clean(cmd)
        if @name.eql? "Clean"
        end
      end

      @microsteps.each do |microstep|
        microstep.commands.map! do |cmd|
          resolve_vars(cmd.val)
        end
      end
      pp @microsteps
    end
  end
end
