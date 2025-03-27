
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

  class Exit < Error; status_code(0) ; end
  class KameleonError < Error; status_code(1) ; end
  class ExecError < Error; status_code(2) ; end
  class InternalError < Error; status_code(3) ; end
  class ContextError < Error; status_code(4) ; end
  class ContextClosed < Error; status_code(4) ; end
  class ShellError < Error; status_code(5) ; end
  class ShellExited < Error; status_code(5) ; end
  class RecipeError < Error; status_code(6) ; end
  class BuildError < Error; status_code(7) ; end
  class AbortError < Error; status_code(8) ; end
  class TemplateNotFound < Error; status_code(9) ; end
  class CacheError < Error; status_code(10) ; end
  class ExportError < Error; status_code(11) ; end
  class RepositoryError < Error; status_code(12) ; end
end
