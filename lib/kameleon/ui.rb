require 'kameleon/engine'

module Kameleon

  # UI handle communication with the outside world
  # They must respond to the typically logger methods
  # of `warn`, `error`, `info`, and `success`.
  class UI
    attr_accessor :env
    attr_accessor :resource

    def initialize(env)
      @env = env
    end

    [:warn, :error, :info, :success].each do |method|
      define_method(method) do |message, *argv|
        opts, *argv = argv
        opts ||= {}
        # Log normal console messages
        env.logger.info("ui") { message }
      end
    end

    [:clear_line, :report_progress, :ask, :no?, :yes?].each do |method|
      # By default do nothing, these aren't logged
      define_method(method) { |*args| }
    end

    # A shell UI, which uses a `Thor::Shell` object to talk with  a terminal.
    class Shell < UI
      def initialize(env, shell)
        super(env)

        @shell = shell
      end

      [[:warn, :yellow], [:error, :red], [:info, nil], [:success, :green]].each do |method, color|
        class_eval <<-CODE
          def #{method}(message, opts = nil)
            super(message)
            opts ||= {}
            opts[:new_line] = true if !opts.has_key?(:new_line)
            @shell.say(message, color.inspect, opts[:new_line])
          end
        CODE
      end

      [:ask, :no?, :yes?].each do |method|
        class_eval <<-CODE
          def #{method}(message, opts = nil)
            super(message)
            opts ||= {}
            @shell.send(method.inspect, message, opts[:color])
          end
        CODE
      end
    end
  end
end
