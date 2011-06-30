require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"

#require 'goalie/rails'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

require 'yaml'
YAML::ENGINE.yamler= 'syck'

module Shapado
  class Application < Rails::Application
    require File.expand_path('../load_config', __FILE__)

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Add additional load paths for your own custom dirs
    config.autoload_paths += %W( #{Rails.root}/app/middlewares #{Rails.root}/app/models/widgets
                                 #{Rails.root}/lib )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    if AppConfig.smtp["activate"]
      config.action_mailer.delivery_method = :smtp
    else
      config.action_mailer.delivery_method = :sendmail
    end
    config.action_mailer.default_url_options = {:host => AppConfig.domain}

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[File.join(Rails.root, 'config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.default_locale = :en

    # middlewares
    config.middleware.use "BugHunter::Middleware"
    config.middleware.use "DynamicDomain"
    config.middleware.use "MongoidExt::FileServer"
    if AppConfig.recaptcha["activate"]
      config.middleware.use "Rack::Recaptcha", :public_key => AppConfig.recaptcha["public_key"],
                                               :private_key => AppConfig.recaptcha["private_key"],
                                               :paths => nil
    end

    if AppConfig.ssl
      require 'rack/ssl'
      config.middleware.use Rack::SSL
    end

    # Configure generators values. Many other options are available, be sure to check the documentation.
    config.generators do |g|
      g.orm             :mongoid
      g.template_engine :haml
      g.test_framework  :rspec, :fixture => true, :views => false
      g.fixture_replacement :fabrication, :dir => "spec/fabricators"
    end

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]
  end
end

# needs to  be required after Rails.root/lib is added to the load path
require "smtp_tls"

