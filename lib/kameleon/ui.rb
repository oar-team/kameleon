module Kameleon
  module UI

    class Silent
      def info(message, newline = nil)
      end

      def confirm(message, newline = nil)
      end

      def warn(message, newline = nil)
      end

      def error(message, newline = nil)
      end

      def debug(message, newline = nil)
      end

      def debug?
        false
      end

      def quiet?
        false
      end

      def ask(message)
      end

      def level=(name)
      end

      def level(name = nil)
      end

      def trace(message, newline = nil)
      end

      def silence
        yield
      end
    end

    class Shell
      LEVELS = %w(silent error warn confirm info verbose debug)

      attr_accessor :shell

      def initialize(options = {})
        @shell = Thor::Base.shell.new
        @level = ENV['KAMELEON_DEBUG'] ? "debug" : "info"
      end

      def info(msg, newline = nil)
        tell_me(msg, nil, newline) if level("info")
      end

      def msg(msg, newline = nil)
        tell_me(msg, :blue, newline) if level("info")
      end

      def confirm(msg, newline = nil)
        tell_me(msg, :green, newline) if level("confirm")
      end

      def warn(msg, newline = nil)
        tell_me(msg, :yellow, newline) if level("warn")
      end

      def error(msg, newline = nil)
        tell_me(msg, :red, newline) if level("error")
      end

      def verbose(msg, newline = nil)
        tell_me("[info] #{msg}", nil, newline) if level("verbose")
      end

      def debug(msg, newline = nil)
        tell_me("[debug] #{msg}", nil, newline) if level("debug")
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
        msg = ["#{e.class}: #{e.message}", *e.backtrace].join("\n")
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
          if Kameleon.log_on_progress
            Kameleon.log_on_progress = false
            msg = "\n" + msg
          end
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
  end
end
