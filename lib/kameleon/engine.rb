require 'kameleon/recipe'
require 'kameleon/shell'
require 'kameleon/error'


module Kameleon
  class Engine
    def initialize(env)
      @options = options
      @recipe = Recipe.new(@options[:recipe_query], @options[:include_paths])
      @local_shell = BasicShell.new
      container = @recipe.global.fetch('container', nil)
      case container
      when nil
        @container_shell = BasicShell.new
      when :kvm
        @container_shell = RemoteShell.new
      when :chroot
        @container_shell = ChrootShell.new
      else
        fail "Invalid container value: #{container}"
      end
    end

    def clean(signal)

    end

    def run
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
  end

end
