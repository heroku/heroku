source "http://rubygems.org"

gem 'heroku-api', :git => 'git://github.com/heroku/heroku.rb.git'
gemspec

group :development do
  gem "aws-s3"
  gem "rake",  ">= 0.8.7"
  gem "rr",    "~> 1.0.2"
  gem "taps",  ">= 0.3.23"
  gem "fpm"
  gem "rubyzip"
end

group :test do
  gem "fakefs"
  gem "jruby-openssl", :platform => :jruby
  gem "json"
  gem "rake",  ">= 0.8.7"
  gem "rr",    "~> 1.0.2"
  gem "rspec", ">= 2.0"
  gem "taps",  ">= 0.3.23"
  gem "webmock"
end
