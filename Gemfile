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
gem 'compass', '0.10.6'
gem "compass-colors", "0.3.1"
gem "fancy-buttons", "1.0.6"
gem 'will_paginate', :git => 'git://github.com/mislav/will_paginate.git', :branch => "rails3"

# mongodb
gem 'bson', '1.2.4'
gem 'bson_ext', '1.2.4'

gem 'mongo', '1.2.4'
gem 'mongoid', '2.0.0'
gem 'mongoid_ext', :git => "git://github.com/dcu/mongoid_ext.git"

# utils

gem 'smart_asset'
gem "whatlanguage", "1.0.0"
gem "uuidtools", "2.1.1"
gem "magent", "0.5.2"

gem 'goalie', '~> 0.0.4'
gem 'dynamic_form'

gem "differ", "0.1.1"
gem "rack-recaptcha", "0.2.2", :require => "rack/recaptcha"

gem "twitter-text", "1.1.8"
gem 'sanitize', '1.2.1'
gem "twitter_oauth"

# authentication
gem 'omniauth', '~> 0.2.0'
gem 'oa-openid', '~> 0.2.0', :require => 'omniauth/openid'
gem "oa-oauth", '~> 0.2.0', :require => "omniauth/oauth"

gem 'multiauth', :git => "http://github.com/dcu/multiauth.git"

gem 'orm_adapter'
gem 'devise', "~> 1.2.1"

gem 'whenever', :require => false
gem 'rack-ssl', :require => false

gem 'state_machine', "0.10.4"

group :scripts do
  gem 'eventmachine', '~> 0.12.10'
  gem 'em-websocket', '~> 0.1.4'
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

