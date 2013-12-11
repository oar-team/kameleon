module Kameleon
  class BasicShell < Session::Bash
    def exec(cmd)
      execute(cmd)
    end
  end

  class CustomShell < BasicShell
  end
end
