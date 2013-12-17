require 'kameleon/recipe'
require 'kameleon/context'


module Kameleon

  attr_accessor :recipe

  class Engine
    def initialize(recipe)
      @recipe = recipe
      @recipe.resolve!
      @recipe.check_recipe
    end

    def do_bootstrap (launch_context)
      if @recipe.sections.key?("bootstrap")
        bootstrap = @recipe.sections.fetch("bootstrap")
        do_steps(bootstrap, launch_context, nil)
      else
        Kameleon.ui.warn "Missing bootstrap section. Skip"
      end
    end

    def do_setup (launch_context, build_context)
      if @recipe.sections.key?("setup")
        setup = @recipe.sections.fetch("setup")
        do_steps(setup, launch_context, build_context)
      else
        Kameleon.ui.warn "Missing setup section. Skip"
      end
    end

    def do_export (launch_context, build_context)
      if @recipe.sections.key?("export")
        export = @recipe.sections.fetch("export")
        do_steps(export, launch_context, build_context)
      else
        Kameleon.ui.warn "Missing export section. Skip"
      end
    end

    def do_steps (section, launch_context, build_context)
        section.each do |macrostep|
          macrostep.microsteps.each do |microstep|
            microstep.commands.each do |cmd|
              case cmd.key
              when "exec"
                build_context.exec(cmd.value)
              when "exec_local"
                launch_context.exec(cmd.value)
              else
                Kameleon.ui.warn "Unknow command : #{cmd.key}"
              end
            end
          end
        end
    end

    def build
      Kameleon.ui.info "====== Starting build ======"
      local_context = LocalContext.new
      check_requirements local_context
      # Do bootstrap
      launch_context = Context.new "launch", @recipe.global["launch_context"]
      do_bootstrap launch_context

      # Do setup
      build_context = Context.new "build", @recipe.global["build_context"]
      do_setup(launch_context, build_context)

      # Do export
      do_export(local_context, build_context)


      # # Launch context shell
      # launch_context = Context.new "launch", @recipe.global["launch_context"]
      # # Do bootstrap
      # begin
      #   #launch_context.exec("debootstrap --arch amd64 wheezy /tmp/test http://ftp.debian.org/debian/")
      # rescue ExecError
      #   # Start Interactive shell
      #   launch_context.start_interactive
      # end

    end

    def check_requirements (local_context)
      requirements = @recipe.global["requirements"]
      Kameleon.ui.info "Checking requirements : #{requirements.join ' '}"
      missings = []
      requirements.each do |cmd|
        missings.push(cmd) unless local_context.check_cmd(cmd)
      end
      fail BuildError, "Missing requirements : #{missings.join ' '}" \
           unless missings.empty?
    end

    private
    def clean(signal)

    end

  end

end
