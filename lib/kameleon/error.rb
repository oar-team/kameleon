module Kameleon
  class Error < ::StandardError; end

  class InternalError < Error; end
  class ArgumentError < Error; end
  class ContextError < Error; end
  class SyntaxError < Error; end
end
