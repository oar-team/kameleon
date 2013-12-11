module Kameleon
  class BasicShell < Session::Bash
    def exec(cmd)
      execute(cmd)
    end
  end

  class CustomShell < BasicShell
    def initialize(exec_cmd)
      self.class::default_prog=exec_cmd
      super()
    end
  end
end
