require 'kameleon/recipe'
require 'pry'

module Kameleon
  class Macrostep

    class Microstep

      class Command
        attr_accessor :string_cmd
        def initialize(yaml_cmd)
          @string_cmd = YAML.dump(yaml_cmd)
        end

        def key
          YAML.load(@string_cmd).keys[0]
        end

        def value
          _, val = YAML.load(@string_cmd).first
          return val
        end
      end

      attr_accessor :commands, :name

      def initialize(yaml_microstep)
        @name, cmd_list = yaml_microstep.first
        @commands = []
        cmd_list.each {|cmd| @commands.push Command.new(cmd)}
      rescue
        fail ExecError, "Invalid microstep \"#{name}\": should be one of the " \
          "defined commands (See documentation)"
      end

    end

    attr_accessor :path, :clean, :microsteps

    def initialize(path, args, recipe)
      @recipe = recipe
      @variables = recipe.global.clone
      @microsteps = []
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @clean = []
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
      fail Error ,"Can't find microstep \"#{microstep_name}\" in macrostep \"#{name}\""
    end

    # Resolve macrosteps variable
    def resolve!()

      #handle clean methods
      def resolve_clean(cmd)
        if !(cmd.key =~ /on_(.*)clean/)
          #Not a clean command
          return cmd
        else
          # Add clean commands to section or macrostep
          clean_microsteps = nil
          Recipe::Section.sections.each do |section|
            if cmd.key.include? section
              clean_microsteps = @recipe.sections.clean[section]
            end
          end
          if clean_microsteps.nil?
            clean_microsteps = @clean
          end
          clean_microsteps.push Microstep.new({"clean_#{@name}" => cmd.value})

          # return nil to remove this command from the step
          return nil
        end
      end

      @microsteps.each do |microstep|
        microstep.commands.map! do |cmd|
          cmd.string_cmd = Utils.resolve_vars(cmd.string_cmd, @path, @variables)
          resolve_clean(cmd)
        end
      end
      # remove nil values
      @microsteps.each { |microsteps| microsteps.commands.compact! }
    end
  end
end
