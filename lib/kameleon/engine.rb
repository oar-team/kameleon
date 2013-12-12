require 'kameleon/error'
require 'kameleon/recipe'
require 'kameleon/shell'


module Kameleon
  class Engine
    def initialize(env, recipe_name)
      @env = env
      @recipe = Recipe.new(@env, recipe_name)
      @local_shell = BasicShell.new
      @container_shell = CustomShell.new @recipe.global.fetch "exec_cmd"
    end

    def build
      @recipe.check_cmds.each { |cmd| @local_shell.check_cmd(cmd) }

      @recipe.sections.each do |section|
        section.macrosteps.each do |macrostep|
          macrostep.each do |microstep|
            microstep.each do |cmd|
              case cmd.key
              when :exec
                @container_shell.exec(cmd.value)
              when :exec_local
                @local_shell.exec(cmd.value)
              else
                @env.ui.warn "Unknow command : #{cmd.key}"
              end
            end
          end
        end
      end
    end

    private
    def clean(signal)

    end

  end

end
