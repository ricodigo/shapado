# Edit this Gemfile to bundle your application's dependencies.
# This preamble is the current preamble for Rails 3 apps; edit as needed.
source 'http://rubygems.org'

gem 'rails', '3.0.6'

if RUBY_PLATFORM !~ /mswin|mingw/
  gem 'rdiscount', '1.6.5'

  gem "ruby-stemmer", "~> 0.8.2", :require => "lingua/stemmer"
  gem "sanitize", "1.2.1"

  gem 'magic'
  gem 'mini_magick', '~> 2.3'
  gem 'nokogiri'
  gem 'mechanize'
else
  gem "maruku", "0.6.0"
end

# ui
gem "haml"
gem "sass"
gem 'compass', '0.11.1'
gem "compass-colors", "0.9.0"
gem "fancy-buttons", "1.1.1"
gem 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :branch => "rails3"

# mongodb
gem 'bson', '1.3.0'
gem 'bson_ext', '1.3.0'

gem 'mongo', '1.3.0'
gem 'mongoid', :git => 'git://github.com/mongoid/mongoid.git'
gem 'mongoid_ext', :git => "git://github.com/dcu/mongoid_ext.git"

# utils

gem 'jammit'
gem "whatlanguage", "1.0.0"
gem "uuidtools", "~> 2.1.1"
gem "magent", "0.6.2"
gem "bug_hunter", "0.0.2"

gem 'goalie', '~> 0.0.4'
gem 'dynamic_form'

gem "rack-recaptcha", "0.2.2", :require => "rack/recaptcha"

gem "twitter-text", "1.1.8"
gem 'sanitize', '1.2.1'
gem "twitter_oauth"

# authentication
gem 'omniauth', '~> 0.2.5'
gem 'oa-openid', '~> 0.2.5', :require => 'omniauth/openid'
gem "oa-oauth", '~> 0.2.5', :require => "omniauth/oauth"

gem 'multiauth', :git => "http://github.com/dcu/multiauth.git"

gem 'orm_adapter'
gem 'devise', "~> 1.2.1"

gem 'whenever', :require => false
gem 'rack-ssl', :require => false

gem 'state_machine', "0.10.4"

group :deploy do
  gem 'capistrano', :require => false
  gem 'ricodigo-capistrano-recipes', "~> 0.1.3", :require => false
  gem 'unicorn', :require => false
end

group :scripts do
  gem 'eventmachine', '~> 0.12.10'
  gem 'em-websocket', '~> 0.3.0'
end

group :test do
  gem 'machinist_mongo', :require => 'machinist/mongoid'
  gem 'ffaker'
  gem 'simplecov'
  gem "autotest"
end

group :development do
  gem "database_cleaner"
  gem "rspec", ">= 2.0.1"
  gem "rspec-rails", ">= 2.0.1"
  gem "remarkable_mongoid", ">= 0.5.0"
  gem 'hpricot'
  gem 'ruby_parser'
  gem 'mongrel', '1.2.0.pre2'
  gem 'niftier-generators', '0.1.2'
  gem 'ruby-prof'
end

