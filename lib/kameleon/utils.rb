require 'pp'
require 'stringio'

module Kameleon
  module Utils

    def self.resolve_vars(raw, yaml_path, initial_variables)
        raw.gsub(/\$\$[a-zA-Z0-9\-_]*/) do |variable|
        # remove the dollars
        strip_variable = variable[2,variable.length]

        # check in local vars
        if initial_variables.has_key? strip_variable
          value = initial_variables[strip_variable]
        else
          fail RecipeError, "#{yaml_path}: variable #{variable} not found in local or global"
        end
        return $` + resolve_vars(value.to_s + $', yaml_path, initial_variables)
      end
    end

    def self.generate_slug(str)
        value = str.strip
        value.gsub!(/['`]/, "")
        value.gsub!(/\s*@\s*/, " at ")
        value.gsub!(/\s*&\s*/, " and ")
        value.gsub!(/\s*[^A-Za-z0-9\.\-]\s*/, '_')
        value.gsub!(/_+/, "_")
        value.gsub!(/\A[_\.]+|[_\.]+\z/, "")
        value
    end

    ### Hash that keeps elements in the insertion order -- it's more
    ### convenient for storing macrostep->microstep->comand structure
    class OrderedHash < Hash
      def initialize
        @key_list = []
        super
      end
      def []=(key, value)
        if has_key?(key)
          super(key, value)
        else
          @key_list.push(key)
          super(key, value)
        end
      end

      def by_index(index)
        self[@key_list[index]]
      end

      def each
        @key_list.each do |key|
          yield( [key, self[key]] )
        end
      end

      def delete(key)
        @key_list = @key_list.delete_if { |x| x == key }
        super(key)
      end
    end
  end
end
