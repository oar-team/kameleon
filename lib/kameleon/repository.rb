require 'kameleon/utils'
require 'kameleon/step'

module Kameleon

  class Repository
    def self.check_git_binary
      git_path ||= Utils.which("git")
      if git_path.nil? then
        raise KameleonError, "git binary not found, make sure it is in your current PATH"
      end
    end

    def self.add(name, url, kwargs = {})
      check_git_binary
      cmd = ["git", "clone"]
      if kwargs[:branch]
        cmd.push("-b", kwargs[:branch])
      end
      cmd.push("--", url, File.join(Kameleon.env.repositories_path, name))
      process = ChildProcess.build(*cmd)
      process.io.inherit!
      process.start
      process.wait
      process.stop
    end

    def self.update(name)
      check_git_binary
      git_repo = File.join(Kameleon.env.repositories_path, name)
      cmd = ["git", "--git-dir", File.join(git_repo, ".git"), "--work-tree",
             git_repo, "--", "pull"]
      process = ChildProcess.build(*cmd)
      process.io.inherit!
      process.start
      process.wait
      process.stop
    end

    def self.list
      Dir["#{Kameleon.env.repositories_path}/*"].each do |repo_path|
        Kameleon.ui.info File.basename("#{repo_path}")
      end
    end
  end
end
