require 'kameleon/recipe'
require 'kameleon/context'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @recipe = recipe
    end

    def build
      Kameleon.ui.info "====== Starting build ======"
      # Local context shell
      local_context = Context.new "local", @recipe.local_cmds_to_check
      # Build context shell
      build_context = Context.new "build", @recipe.cmds_to_check, @recipe.global["exec_cmd"]
      @recipe.sections.each do |section|
        section.macrosteps.each do |macrostep|
          macrostep.each do |microstep|
            microstep.each do |cmd|
              case cmd.key
              when :exec
                local_context.exec(cmd.value)
              when :exec_local
                build_context.exec(cmd.value)
              else
                Kameleon.ui.warn "Unknow command : #{cmd.key}"
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
