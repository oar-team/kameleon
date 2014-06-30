$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)

require "bundler"
require "thor/rake_compat"

class Default < Thor
  include Thor::RakeCompat
  Bundler::GemHelper.install_tasks

  desc "build", "Build kameleon-#{Kameleon::VERSION}.gem into the pkg directory"
  def build
    Rake::Task["build"].execute
  end

  desc "install", "Build and install kameleon-#{Kameleon::VERSION}.gem into system gems"
  def install
    Rake::Task["install"].execute
  end

  desc "release", "Create tag #{Kameleon::VERSION} and build and push kameleon-#{Kameleon::VERSION}.gem to Rubygems"
  def release
    Rake::Task["release"].execute
  end

  desc "spec", "Run RSpec code examples"
  def spec
    exec "rspec spec"
  end
end
