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

    def self.update(name=nil)
      repo_list = Dir["#{Kameleon.env.repositories_path}/*"]
      raise RepositoryError, "No repository defined" if repo_list.empty?
      if name.nil?
        raise RepositoryError, "More than one repository, select one of " + repo_list.join(", ") if repo_list.size > 1
        name = Dir["#{Kameleon.env.repositories_path}/*"].first
      end
      check_git_binary
      git_repo = File.join(Kameleon.env.repositories_path, name)
      raise RepositoryError, "Repository not found '#{name}'" if not File.directory?(git_repo)
      cmd = ["git", "--git-dir", File.join(git_repo, ".git"), "--work-tree",
             git_repo, "pull", "--verbose", "--ff-only"]
      process = ChildProcess.build(*cmd)
      process.io.inherit!
      process.start
      process.wait
      process.stop
    end

    def self.list(kwargs = {})
      Dir["#{Kameleon.env.repositories_path}/*"].each do |repo_path|
        if kwargs[:git]
          show_git_repository(repo_path)
        else
          Kameleon.ui.info File.basename(repo_path)
        end
      end
    end

    def self.remove(name)
      repo_path = File.join(Kameleon.env.repositories_path, name)
      raise RepositoryError, "Repository not found '#{name}'" if not File.directory?(repo_path)
      Kameleon.ui.shell.say "Removing: ", :red, false
      show_git_repository(repo_path)
      FileUtils.rm_rf(repo_path)
    end

    def self.show_git_repository(repo_path)
      cmd = ["git", "remote", "-v"]
      r, w = IO.pipe
      process = ChildProcess.build(*cmd)
      process.io.stdout = w
      process.cwd = repo_path
      process.start
      w.close
      url = r.readline.split[1]
      process.wait
      process.stop
      cmd = ["git", "rev-parse", "--abbrev-ref", "HEAD"]
      r, w = IO.pipe
      process = ChildProcess.build(*cmd)
      process.io.stdout = w
      process.cwd = repo_path
      process.start
      w.close
      branch = r.readline.chomp
      process.wait
      process.stop
      Kameleon.ui.shell.say "#{File.basename("#{repo_path}")}", nil, false
      Kameleon.ui.shell.say " <-", :magenta, false
      Kameleon.ui.shell.say " #{url}", :cyan, false
      Kameleon.ui.shell.say " (#{branch})", :yellow
    end
  end
end
