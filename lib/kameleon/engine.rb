require 'kameleon/recipe'
require 'kameleon/context'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @recipe = recipe
      @recipe.resolve!
      @recipe.check_recipe
      @local_context = LocalContext.new
    end

    def build
      Kameleon.ui.info "====== Starting build ======"
      # Local context

      check_requirements
      # Launch context shell
      launch_context = Context.new "launch", @recipe.global["launch_context"]
      # Do bootstrap
      begin
        #launch_context.exec("debootstrap --arch amd64 wheezy /tmp/test http://ftp.debian.org/debian/")
      rescue ExecError
        # Start Interactive shell
        launch_context.start_interactive
      end

      # Do Setup

      # Do export

      # Do clean

      #Build context shell
      build_context = Context.new "build", @recipe.cmds_to_check, @recipe.global["local_context"]
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
    def check_requirements
      requirements = @recipe.global["requirements"]
      Kameleon.ui.info "Checking requirements : #{requirements.join ' '}"
      missings = []
      requirements.each do |cmd|
        missings.push(cmd) unless @local_context.check_cmd(cmd)
      end
      fail BuildError, "Missing requirements : #{missings.join ' '}" \
           unless missings.empty?
    end

    private
    def clean(signal)

    end

  end

end
