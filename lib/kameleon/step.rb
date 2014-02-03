module Kameleon

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
      if object.kind_of? Command
        return object
      end
      _, val = object.first
      # Nested commands
      if val.kind_of? Array
        val = val.map { |item| Command.new(item) }
      end
      val
    end

    def to_array
      if value.kind_of? Array
        return value.map { |val| val.to_array }
      else
        return { key => value }
      end
    end

  end

  class Microstep
    attr_accessor :commands, :name, :identifier, :slug, :in_cache,
                  :on_checkpoint, :order

    def initialize(string_or_hash)
      @identifier = nil
      @in_cache = false
      @on_checkpoint = "use_cache"
      @commands = []
      @name, cmd_list = string_or_hash.first
      cmd_list.each do |cmd_hash|
        if cmd_hash.kind_of? Command
          @commands.push cmd_hash
        else
          if cmd_hash.kind_of?(Hash) && cmd_hash.keys.first == "on_checkpoint"
            @on_checkpoint = cmd_hash["on_checkpoint"]
          else
            @commands.push Command.new(cmd_hash)
          end
        end
      end
    rescue
      fail RecipeError, "Syntax error for microstep #{name}"
    end

    def unshift(cmd_list)
      cmd_list.reverse.each {|cmd| @commands.unshift cmd}
    end

    def push(cmd)
      @commands.push cmd
    end

    def calculate_identifier(salt)
      commands_str = @commands.map { |cmd| cmd.string_cmd.to_s }
      content_id = commands_str.join(' ') + salt
      @identifier = "#{ Digest::SHA1.hexdigest content_id }"[0..11]
    end

    def to_array
      microstep_array = @commands.map do |cmd|
        cmd.to_array
      end
      return microstep_array
    end

  end

  class Macrostep
    attr_accessor :name, :clean_microsteps, :init_microsteps, :microsteps,
                  :path, :variables

    def initialize(name, microsteps, variables, path)
      @name = name
      @variables = variables
      @path = path
      @microsteps = microsteps
      @clean_microsteps = []
      @init_microsteps = []
    end

    def resolve_variables!(global)
      # Resolve dynamically-defined variables !!
      tmp_resolved_vars = {}
      @variables.clone.each do |key, value|
        yaml_vars = { key => value }.to_yaml
        yaml_resolved = Utils.resolve_vars(yaml_vars,
                                           @path,
                                           tmp_resolved_vars.merge(global))
        tmp_resolved_vars.merge! YAML.load(yaml_resolved)
      end
      @variables.merge! tmp_resolved_vars
      @microsteps.each do |m|
        m.commands.each do |cmd|
          cmd.string_cmd = Utils.resolve_vars(cmd.string_cmd,
                                              @path,
                                              global.merge(@variables))
        end
      end
    end

    def sequence
      @init_microsteps.each { |m| yield m }
      @microsteps.each { |m| yield m }
      @clean_microsteps.each  { |m| yield m }
    end

    def to_array
      macrostep_array = []
      @variables.each do |k, v|
        macrostep_array.push({ k => v })
      end
      sequence do |microstep|
        macrostep_array.push({ microstep.name => microstep.to_array })
      end
      return macrostep_array
    end

  end

  class Section
    attr_accessor :name, :clean_macrostep, :init_macrostep, :macrosteps

    def initialize(name)
      @name = name
      @clean_macrostep = Macrostep.new("_clean_#{name}", [], {}, nil)
      @init_macrostep = Macrostep.new("_init_#{name}", [], {}, nil)
      @macrosteps = []
    end

    def sequence
      yield @init_macrostep
      @macrosteps.each { |m| yield m }
      yield @clean_macrostep
    end

    def to_array
      section_array = []
      sequence do |macrostep|
        macrostep.sequence do |microstep|
          hash = {
            "identifier" => microstep.identifier.to_s,
            "cmds" => microstep.to_array
          }
          section_array.push({ microstep.slug => hash })
        end
      end
      return section_array
    end
  end

end
