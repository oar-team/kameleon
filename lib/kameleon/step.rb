module Kameleon

  class Command

    attr_accessor :string_cmd
    attr_accessor :raw_cmd_id
    attr_accessor :microstep_name
    attr_accessor :identifier

    def initialize(yaml_cmd, microstep_name)
      @string_cmd = YAML.dump(yaml_cmd).gsub("---", "").strip
      @raw_cmd_id = Digest::SHA1.hexdigest(YAML.dump(yaml_cmd).gsub("---", "").strip)
      @microstep_name = microstep_name
      @identifier = nil
    end

    def resolve!
      key
      value
    end

    def key
      if @key.nil?
        object = YAML.load(@string_cmd)
        if object.kind_of? String
          @key = object
        else
          @key = object.keys.first
        end
      end
      @key
    rescue
      lines = @string_cmd.split( /\r?\n/ ).map {|l| "> #{l}" }
      fail RecipeError, "Syntax error for microstep #{@microstep_name} : \n"\
                        "#{ lines.join "\n"}"
    end

    def value
      if @value.nil?
        Kameleon.ui.debug("Parsed string = #{@string_cmd}")
        object = YAML.load(@string_cmd)
        if object.kind_of? Command
          @value = object
        elsif object.kind_of? String
          @value = nil
        else
          raise RecipeError unless object.kind_of? Hash
          raise RecipeError unless object.keys.count == 1
          _, val = object.first
          unless val.kind_of?(Array)
            val = val.to_s
          end
          # Nested commands
          if val.kind_of? Array
            val = val.map { |item| Command.new(item, @microstep_name) }
          end
          @value = val
        end
      end
      @value
    rescue
      fail RecipeError, "Syntax error after variable resolution for microstep #{@microstep_name}, parsed string =\n"\
                        "#{@string_cmd}\n"\
                        "Maybe you should remove trailing newline from variable using '>-' or '|-'"
    end

    def to_array
      if value.kind_of? Array
        map = value.map { |val| val.to_array }
        return { key => map }
      else
        return { key => value }
      end
    end

    def string_cmd=(str)
      Kameleon.ui.debug("Set string_cmd to '#{str}' and clear cached value")
      @string_cmd = str
      @value = nil
    end

    def remaster_string_cmd_from_value!
      self.string_cmd = YAML.dump(to_array).gsub("---", "").strip
      return self
    end

    def gsub!(arg1, arg2)
      if value.kind_of? Array
        value.each { |cmd| cmd.gsub!(arg1, arg2) }
      else
        @value.gsub!(arg1, arg2)
      end
      remaster_string_cmd_from_value!
      return self
    end

  end

  class Microstep
    attr_accessor :commands
    attr_accessor :name
    attr_accessor :identifier
    attr_accessor :slug
    attr_accessor :in_cache
    attr_accessor :on_checkpoint
    attr_accessor :order

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
            @commands.push Command.new(cmd_hash, @name)
          end
        end
      end
    rescue
      fail RecipeError, "Syntax error for microstep #{name}"
    end

    def resolve!
      @commands.each {|cmd| cmd.resolve! }
    end

    def gsub!(arg1, arg2)
      @commands.each {|cmd| cmd.gsub!(arg1, arg2) }
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
      @commands.each do |cmd|
        map_id = cmd.string_cmd.to_s + @identifier
        cmd.identifier = "#{ Digest::SHA1.hexdigest map_id }"[0..11]
      end
      @identifier
    end

    def to_array
      microstep_array = @commands.map do |cmd|
        cmd.to_array
      end
      return microstep_array
    end

  end

  class Macrostep
    attr_accessor :name
    attr_accessor :clean_microsteps
    attr_accessor :init_microsteps
    attr_accessor :microsteps
    attr_accessor :path
    attr_accessor :variables

    def initialize(name, microsteps, variables, path)
      @name = name
      @variables = variables
      @path = path
      @microsteps = microsteps
      @clean_microsteps = []
      @init_microsteps = []
    end

    def resolve_variables!(global, recipe)
      # Resolve dynamically-defined variables !!
      tmp_resolved_vars = {}
      @variables.clone.each do |key, value|
        yaml_vars = { key => value }.to_yaml.chomp
        yaml_resolved = Utils.resolve_vars(yaml_vars,
                                           @path,
                                           tmp_resolved_vars.merge(global),
                                           recipe)
        tmp_resolved_vars.merge! YAML.load(yaml_resolved.chomp)
      end
      @variables.merge! tmp_resolved_vars
      @microsteps.each do |m|
        m.commands.each do |cmd|
          cmd.string_cmd = Utils.resolve_vars(cmd.string_cmd,
                                              @path,
                                              global.merge(@variables),
                                              recipe)
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
    attr_accessor :name
    attr_accessor :clean_macrostep
    attr_accessor :init_macrostep
    attr_accessor :macrosteps

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
