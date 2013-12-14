require 'rubygems/user_interaction'

module Kameleon
  # UI handle communication with the outside world
  # They must respond to the typically logger methods
  # of `warn`, `error`, `info`, and `confirm`.
  class UI
    [:warn, :debug, :trace, :error, :info, :confirm].each do |method|
      define_method(method) do |message, newline = nil|
      end
    end

    [:ask, :no?, :yes?].each do |method|
      # By default do nothing, these aren't logged
      define_method(method) { |*args| }
    end

    class Shell < UI
      LEVELS = %w(silent error warn confirm info debug)

      attr_writer :shell

      def initialize(options = {})
        if options["no_color"] || !STDOUT.tty?
          Thor::Base.shell = Thor::Shell::Basic
        end
        @shell = Thor::Base.shell.new
        @level = ENV['DEBUG'] ? "debug" : "info"
      end

      [[:info, nil], [:confirm, :green], [:warn, :yellow], [:error, :red], [:debug, nil]].each do |method, color|
        class_eval <<-CODE
          def #{method}(msg, newline = nil)
            tell_me(msg, #{color.inspect}, newline) if level("#{method}")
          end
        CODE
      end

      def debug?
        # needs to be false instead of nil to be newline param to other methods
        level("debug")
      end

      def quiet?
        LEVELS.index(@level) <= LEVELS.index("warn")
      end

      def ask(msg)
        @shell.ask(msg)
      end

      def level=(level)
        raise ArgumentError unless LEVELS.include?(level.to_s)
        @level = level
      end

      def level(name = nil)
        name ? LEVELS.index(name) <= LEVELS.index(@level) : @level
      end

      def trace(e, newline = nil)
        msg = ["Traceback => #{e.class} : #{e.message}", *e.backtrace].join("\n ~> ")
        if debug?
          tell_me(msg, nil, newline)
        elsif @trace
          STDERR.puts "#{msg}#{newline}"
        end
      end

      def silence
        old_level, @level = @level, "silent"
        yield
      ensure
        @level = old_level
      end

    private

      # valimism
      def tell_me(msg, color = nil, newline = nil)
        msg = word_wrap(msg) if newline.is_a?(Hash) && newline[:wrap]
        if newline.nil?
          @shell.say(msg, color)
        else
          @shell.say(msg, color, newline)
        end
      end

      def strip_leading_spaces(text)
        spaces = text[/\A\s+/, 0]
        spaces ? text.gsub(/#{spaces}/, '') : text
      end

      def word_wrap(text, line_width = @shell.terminal_width)
        strip_leading_spaces(text).split("\n").collect do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end
    end

    class RGProxy < ::Gem::SilentUI
      def initialize(ui)
        @ui = ui
        super()
      end

      def say(message)
        if message =~ /native extensions/
          @ui.info "with native extensions "
        else
          @ui.debug(message)
        end
      end
    end
  end
end
