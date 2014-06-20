require 'thor/error'

module Kameleon
  class Error < ::StandardError
    attr_accessor :object

    def initialize(message=nil, object=nil)
      super(message)
      self.object = object
    end

    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class KameleonError < Error; status_code(1) ; end
  class ExecError < Error; status_code(2) ; end
  class InternalError < Error; status_code(3) ; end
  class ContextError < Error; status_code(4) ; end
  class ShellError < Error; status_code(5) ; end
  class RecipeError < Error; status_code(6) ; end
  class BuildError < Error; status_code(7) ; end
  class AbortError < Error; status_code(8) ; end
  class TemplateNotFound < Error; status_code(9) ; end

  def self.with_friendly_errors
    yield
  rescue Kameleon::Error => e
    e.message.split( /\r?\n/ ).each {|m| Kameleon.logger.fatal m }
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
  rescue Errno::ENOENT => e
    $stderr << "#{e.message}\n"
    e.backtrace.each {|m| Kameleon.logger.debug m }
    exit 16
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
