require 'progressbar'

module Kameleon
  module Utils

    @@warned_vars = Array.new
    def self.warn_var(var)
      if ! @@warned_vars.include?(var)
        Kameleon.ui.warn("Warning : variable $$#{var[0]} is not enclosed with braces, which may cause errors. Please prefer using $${#{var[0]}}.")
        @@warned_vars.push(var)
      end
    end


    def self.resolve_vars(raw, yaml_path, initial_variables, recipe, kwargs = {})
      raw = resolve_data_dir_vars(raw, yaml_path, initial_variables, recipe, kwargs)
      return resolve_simple_vars(raw, yaml_path, initial_variables, kwargs)
    end

    def self.resolve_data_dir_vars(raw, yaml_path, initial_variables, recipe, kwargs)
      raw.to_s.scan(/\$\$kameleon\_data\_dir\/(.*)/) do |var|
        warn_var(var)
      end
      reg = %r/(\$\$kameleon\_data\_dir|\$\${kameleon\_data\_dir})(.*)/
      matches = raw.to_enum(:scan, reg).map { Regexp.last_match }
      matches.each do |m|
        unless m.nil?
          path = resolve_simple_vars(m[2], yaml_path, initial_variables, kwargs)
          resolved_path = recipe.resolve_data_path(path.chomp('"'), yaml_path)
          raw.gsub!(m[0].chomp('"'), "#{resolved_path}")
        end
      end
      return raw
    end

    def self.resolve_simple_vars_once(raw, initial_variables)
      raw.to_s.scan(/\$\$([a-zA-Z0-9\-_]+)/) do |var|
        warn_var(var)
      end
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
        end
        return $` + value.to_s + $'
      end
    end


    # Variables are replaced correctly for recursive variable overload of
    # the parent by the child:
    # For example:
    #   Parent={var: 10}
    #   Child={var: $$var 11}
    #   => {var: 10 11}
    def self.overload_merge(parent_dict, child_dict)
      parent_dict.merge(child_dict){ |key, old_value, new_value|
        if new_value.to_s.include?("$$" + key.to_s) or new_value.to_s.include?("$${" + key.to_s + "}")
          Utils.resolve_simple_vars_once(new_value, {key => old_value})
        else
          new_value
        end
      }
    end


    def self.resolve_simple_vars(raw, yaml_path, initial_variables, kwargs)
      raw.to_s.scan(/\$\$([a-zA-Z0-9\-_]+)/) do |var|
        warn_var(var)
      end
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
          Kameleon.ui.debug("Resolved variable = #{strip_var}: #{value}")
        else
          if kwargs.fetch(:strict, true)
            fail RecipeError, "#{yaml_path}: variable #{var} not found in local or global"
          end
        end
        return $` + resolve_simple_vars(value.to_s + $', yaml_path, initial_variables, kwargs)
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
        value.chomp("_").downcase
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

    def self.copy_files(relative_dir, dest_dir, files2copy)
      files2copy.each do |path|
        relative_path = path.relative_path_from(relative_dir)
        dst = File.join(dest_dir,relative_path)
        FileUtils.mkdir_p File.dirname(dst)
        FileUtils.copy_file(path, dst)
      end
    end

    def self.list_recipes(recipes_path, filter = ".*", do_progressbar = false, is_repository = false, kwargs = {})
      Kameleon.env.root_dir = recipes_path
      catch_exception = kwargs.fetch(:catch_exception, true)
      recipes_hash = []
      recipes_files = get_recipes(recipes_path).select { |f| Regexp.new(filter).match(f.to_s.gsub(recipes_path.to_s + '/', '').chomp('.yaml')) }
      if recipes_files.empty?
        Kameleon.ui.shell.say "  <None>", :cyan
        return
      end
      if do_progressbar
        progressbar = ProgressBar.create(:format         => '%t (%p%%) %bᗧ%i',
                                         :title          => 'Resolving ' + if is_repository; 'templates' else  'recipes' end,
                                         :progress_mark  => '.',
                                         :remainder_mark => '･',
                                         :total          => recipes_files.size + 10,
                                         :starting_at    => 10)
      end
      recipes_files.each do |f|
        path = f.to_s
        begin
        recipe = RecipeTemplate.new(path)
        name = path.gsub(recipes_path.to_s + '/', '').chomp('.yaml')
        recipes_hash.push({
          "name" => name,
          "description" => recipe.metainfo['description'],
        })
        progressbar.increment if do_progressbar
        rescue => e
          raise e if Kameleon.env.debug or not catch_exception
        end
      end
      unless recipes_hash.empty?
        name_width = recipes_hash.map { |k| k['name'].size }.max
        desc_width = Kameleon.ui.shell.terminal_width - name_width - 3
        desc_width = (80 - name_width - 3) if desc_width < 0
      end
      repo_str_old = nil
      recipes_hash.sort_by{ |k| k["name"] }.each do |r|
        if is_repository
          repo_str,recipe_dir_str,recipe_str = r["name"].match(%r{^([^/]+/)(.+/)?([^/]+)$}).to_a[1..3].map{|m| m.to_s}
        else
          repo_str,recipe_dir_str,recipe_str = r["name"].match(%r{^()(.+/)?([^/]+)$}).to_a[1..3].map{|m| m.to_s}
        end
        if not repo_str_old.nil? and repo_str_old != repo_str
          Kameleon.ui.shell.say "#{'-' * name_width} | #{'-' * desc_width}"
        end
        repo_str_old = repo_str
        Kameleon.ui.debug("#{r["name"]} -> repo=#{repo_str}, recipe_dir=#{recipe_dir_str}, recipee=#{recipe_str}")
        Kameleon.ui.shell.say "#{repo_str}", :yellow, false
        Kameleon.ui.shell.say "#{recipe_dir_str}", :cyan, false
        Kameleon.ui.shell.say sprintf("%-#{name_width - repo_str.length - recipe_dir_str.length}s", recipe_str), :magenta, false
        Kameleon.ui.shell.say " | ", nil, false
        if r["description"].to_s.length > desc_width - 4
          r["description"] = r["description"][0..(desc_width - 4)] + "..."
        end
        Kameleon.ui.shell.say sprintf("%-#{desc_width}s", r["description"]), :blue
      end
    end

    def self.get_recipes(path)
      path.children.collect do |child|
        if child.file?
          if child.extname == ".yaml"
            unless child.to_s.include? "/steps/" or child.to_s.include? "/.steps/"
              child
            end
          end
        elsif child.directory?
          get_recipes(child)
        end
      end.select { |x| x }.flatten(1)
    end

    def self.which(cmd)
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exe = File.join(path, "#{cmd}")
        return path if File.executable? exe
      end
      return nil
    end
  end
end
