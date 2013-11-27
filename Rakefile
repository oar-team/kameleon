require 'bundler/gem_tasks'
begin
  require 'rspec/core/rake_task'
  require 'coveralls/rake/task'

  # desc 'Run all specs'
  # task :test => ['test:unit', 'test:acceptance']

  desc 'Default task which runs all specs with code coverage enabled'
  task :default => ['test:set_coverage', 'test:unit']

  # Coveralls::RakeTask.new
  # task :ci => ['test:set_coverage', 'test:unit', 'coveralls:push']
rescue LoadError; end

namespace :test do
  task :set_coverage do
    ENV['COVERAGE'] = 'true'
  end

  RSpec::Core::RakeTask.new("unit") do |t|
    t.name = "unit"
    t.pattern = "tests/unit/*_test.rb"
  end

  # RSpec::Core::RakeTask.new do |t|
  #   t.name = "acceptance"
  #   t.pattern = "test/acceptance/*_test.rb"
  # end

end
