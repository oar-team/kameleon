# Based on: http://www.programmersparadox.com/2012/05/21/gemspec-loading-dependent-gems-based-on-the-users-system/

# This file needs to be named mkrf_conf.rb
# so that rubygems will recognize it as a ruby extension
# file and not think it is a C extension file

jruby = defined?(JRUBY_VERSION) || (defined?(RUBY_ENGINE) && 'jruby' == RUBY_ENGINE)
rbx = defined?(RUBY_ENGINE) && 'rbx' == RUBY_ENGINE

def already_installed(dep)
  !Gem::DependencyInstaller.new(:domain => :local).find_gems_with_sources(dep).empty? ||
  !Gem::DependencyInstaller.new(:domain => :local,:prerelease => true).find_gems_with_sources(dep).empty?
end

# Load up the rubygem's dependency installer to
# installer the gems we want based on the version
# of Ruby the user has installed

unless jruby || rbx
  require 'rubygems'
  require 'rubygems/command.rb'
  require 'rubygems/dependency.rb'
  require 'rubygems/dependency_installer.rb'



  begin
    Gem::Command.build_args = ARGV
    rescue NoMethodError
  end

  if RUBY_VERSION > "2.0"
      dep = Gem::Dependency.new("syck", '> 0')
  end

  begin
    puts "Installing base gem"
    inst = Gem::DependencyInstaller.new
    inst.install dep
  rescue
    inst = Gem::DependencyInstaller.new(:prerelease => true)
    begin
      inst.install dep
    rescue Exception => e
      puts e
      puts e.backtrace.join "\n  "
      exit(1)
    end
  end unless dep.nil? || already_installed(dep)
end

# If this was C, rubygems would attempt to run make
# Since this is Ruby, rubygems will attempt to run rake
# If it doesn't find and successfully run a rakefile, it errors out
f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")
f.write("task :default\n")
f.close

