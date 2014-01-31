require 'thor/error'

module Kameleon
  class KameleonError < ::StandardError
    attr_accessor :object

    def initialize(message=nil, object=nil)
      super(message)
      self.object = object
    end

    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class ExecError < KameleonError; status_code(2) ; end
  class InternalError < KameleonError; status_code(3) ; end
  class ContextError < KameleonError; status_code(4) ; end
  class ShellError < KameleonError; status_code(5) ; end
  class RecipeError < KameleonError; status_code(6) ; end
  class BuildError < KameleonError; status_code(7) ; end
  class AbortError < KameleonError; status_code(8) ; end

  def self.with_friendly_errors
    yield
  rescue Kameleon::KameleonError => e
    Kameleon.logger.fatal("#{e.message}")
    exit e.status_code
  rescue Thor::UndefinedTaskError => e
    $stderr << "#{e.message}\n"
    e.backtrace.each {|m| Kameleon.logger.debug m }
    exit 15
  rescue Thor::Error => e
    $stderr << "#{e.message}\n"
    e.backtrace.each {|m| Kameleon.logger.debug m }
    exit 15
  rescue SystemExit, Interrupt => e
    Kameleon.logger.fatal("Quitting...")
    exit 1
  rescue Exception => e
    if ENV["KAMELEON_LOG"] != "debug"
      $stderr << "Unfortunately, a fatal error has occurred : "\
                 "#{e.message}.\nUse --debug option for more details\n"
    else
      Kameleon.logger.debug "Error : #{e}"
      e.backtrace.each {|m| puts "==> #{m}" }
    end
    exit 666
  end
end
