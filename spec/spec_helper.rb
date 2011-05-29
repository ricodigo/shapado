# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require 'simplecov'
SimpleCov.start 'rails'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'remarkable/mongoid'
require File.expand_path(File.dirname(__FILE__) + "/blueprints")

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}


RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
#   config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  #   config.use_transactional_fixtures = false

  config.after :suite do
    Mongoid.master.collections.select do |collection|
      collection.name !~ /system/
    end.each(&:drop)
  end

  def stub_authentication(user = nil)
    @user = user || User.make(:user)
    Thread.current[:current_user] = @user
    sign_in @user
    controller.stub!(:current_user).and_return(@user)
    @user
  end

  def stub_group(group = nil)
    group ||= Group.make(:group)
    @controller.stub!(:find_group)
    @controller.stub!(:current_group).and_return(group)
    group
  end

  require 'database_cleaner'
  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.orm = "mongoid"
  end

  config.before(:each) do
    Sham.reset(:before_all)
#     Sham.reset(:before_each)
    DatabaseCleaner.clean
  end
end
