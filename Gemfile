source "https://rubygems.org"

gem "syck", :platforms => [:ruby_20,  :ruby_21]

group :development do
  gem "pry"
  gem "rake"
  platforms :ruby_19, :ruby_20 do
    gem "pry-debugger"
    gem "pry-stack_explorer"
  end
end

group :test do
  gem "coveralls", ">= 0.5.7", :require => false
  gem "rspec", ">= 3"
  gem "rspec-mocks", ">= 3"
  gem "rubocop", ">= 0.19", :platforms => [:ruby_19, :ruby_20, :ruby_21]
  gem "simplecov", :require => false
end

gemspec
