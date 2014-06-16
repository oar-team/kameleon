module Kameleon
  module Utils

    def self.resolve_vars(raw, yaml_path, initial_variables, kwargs = {})
      strict = kwargs.fetch(:strict, true)
      raw.to_s.gsub(/\$\$\{[a-zA-Z0-9\-_]+\}|\$\$[a-zA-Z0-9\-_]+/) do |var|
        # remove the dollars
        if var.include? "{"
          strip_var = var[3,(var.length - 4)]
        else
          strip_var = var[2,(var.length - 2)]
        end
        # check in local vars
        if initial_variables.has_key? strip_var
          value = initial_variables[strip_var]
        else
          if strict
            fail RecipeError, "#{yaml_path}: variable #{var} not found in local or global" \
          end
        end
        return $` + resolve_vars(value.to_s + $', yaml_path, initial_variables, kwargs)
      end
    end

    def self.generate_slug(str)
        value = str.strip
        value.gsub!(/['`]/, "")
        value.gsub!(/\s*@\s*/, " at ")
        value.gsub!(/\s*&\s*/, " and ")
        value.gsub!(/\s*[^A-Za-z0-9\.]\s*/, '_')
        value.gsub!(/_+/, "_")
        value.gsub!(/\A[_\.]+|[_\.]+\z/, "")
        value
    end

    def self.extract_meta_var(name, content)
        start_regex = Regexp.escape("# #{name.upcase}: ")
        end_regex = Regexp.escape("\n#\n")
        reg = %r/#{ start_regex }(.*?)#{ end_regex }/m
        var = content.match(reg).captures.first
        var.gsub!("\n#", "")
        var.gsub!("  ", " ")
        return var
    rescue
    end

  end
end
