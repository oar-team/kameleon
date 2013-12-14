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
end
