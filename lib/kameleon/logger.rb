require 'log4r-color'

module Kameleon
  # Custom Log4r formatter for the console
  class ConsoleFormatter < Log4r::BasicFormatter
    @@basicformat = "%*s"

    def initialize(hash={})
      super(hash)
      @max_level_length = 11
      @on_progress = false
    end

    def format(event)
      buff = sprintf(@@basicformat, @max_level_length, event.name)
      buff << (event.tracer.nil? ? "" : "(#{event.tracer[0]})") + ": "
      unless Log4r::LNAMES[event.level].include? "PROGRESS"
        @on_progress = false
        buff << format_object(event.data) + "\n"
      else
        if @on_progress
          event.data
        else
          @on_progress = true
          buff << format_object(event.data)
        end
      end
    end
  end

  # Custom Log4r formatter for files
  class FileFormatter < Log4r::BasicFormatter

    def initialize(hash={})
      super(hash)
    end

    def format(logevent)
      unless Log4r::LNAMES[event.level].include? "PROGRESS"
        # Formats the data as is with no newline, to allow progress bars to be logged.
        sprintf("%s", logevent.data.to_s)
      else
        if logevent.data.kind_of? String
          # remove ^M characters
          logevent.data.gsub!(/\r/, "")
          # Prevent two newlines in the log file
          logevent.data.chop! if logevent.data =~ /\n$/
        end
        sprintf("[%8s %s] %s\n", Log4r::LNAMES[logevent.level], Time.now.strftime("%m/%d/%Y %I:%M:%S %p"), format_object(logevent.data))
      end
    end
  end
end
