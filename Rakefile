require 'bundler/gem_tasks'
require 'rake/testtask'

begin
  require 'coveralls/rake/task'

  Coveralls::RakeTask.new
  task :ci => ['set_coverage', 'test', 'coveralls:push']
rescue LoadError; end


task :set_coverage do
  ENV['COVERAGE'] = 'true'
end


Rake::TestTask.new do |t|
  t.libs << 'tests'
  t.pattern = "tests/test_*.rb"
end


desc 'Default task which runs all tests with code coverage enabled'
task :default => ['set_coverage', 'test']
