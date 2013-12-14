require 'thor/error'

module Kameleon
  class KameleonError < ::StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
    end
  end

  class ExecError < KameleonError; status_code(2) ; end
  class InternalError < KameleonError; status_code(3) ; end
  class ArgumentError < KameleonError; status_code(4) ; end
  class ContextError < KameleonError; status_code(5) ; end
  class SyntaxError < KameleonError; status_code(6) ; end


  def self.with_friendly_errors
    yield
  rescue Kameleon::KameleonError => e
    Kameleon.ui.error e.message, :wrap => true
    Kameleon.ui.trace e
    exit e.status_code
  rescue Thor::UndefinedTaskError => e
    Kameleon.ui.error e.message
    exit 15
  rescue Thor::Error => e
    Kameleon.ui.error e.message
    exit 15
  rescue Interrupt => e
    Kameleon.ui.error "\nQuitting..."
    Kameleon.ui.trace e
    exit 1
  rescue SystemExit => e
    exit e.status
  rescue Exception => e
    Kameleon.ui.debug "Unexpected error occurred :\n#{e}"
    Kameleon.ui.error <<-ERR, :wrap => true
Unfortunately, a fatal error has occurred. Use --debug option for more details
ERR
    raise e
  end
end
