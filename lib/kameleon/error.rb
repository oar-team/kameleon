module Kameleon
  class Error < ::StandardError; end

  class ExecError < Error; end
  class InternalError < Error; end
  class ArgumentError < Error; end
  class ContextError < Error; end
  class SyntaxError < Error; end
end
