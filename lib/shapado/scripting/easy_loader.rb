ENV["SHAPADO_NO_CHECK_CONFIG"] = "1"

Dir.chdir(File.dirname(__FILE__)) do
  require 'bundler/setup'
  Bundler.setup
end

Dir.chdir(Bundler.root.to_s)

require 'rails'
require 'action_mailer/railtie'
require 'action_controller'
require 'action_view'
require "#{Bundler.root}/lib/shapado/scripting/application"

require 'mongoid'
require 'mongoid_ext'
require 'devise'
require 'devise/rails'
require 'state_machine'
require 'magent'
require 'haml'
require 'haml/template'
require 'sass'

Rails.logger = Logger.new("#{Rails.root}/log/#{File.basename($0).parameterize.to_s}.log")

Dir.chdir(Rails.root.to_s) do
  $:.unshift ::File.expand_path("app/helpers")
  $:.unshift ::File.expand_path("lib")

  Mongoid.load!("./config/mongoid.yml")
  Magent.setup(YAML.load_file(Rails.root.join('config', 'magent.yml')),
                  Rails.env, {})

  MongoidExt.init

  # initializers
  require './vendor/plugins/i18n_action_mailer/lib/i18n_action_mailer'
  require './config/initializers/00_config'
  require './config/initializers/01_locales'
  require './config/initializers/constants'
  require './config/initializers/devise'

  ActiveSupport::Dependencies.mechanism = :require
  ActiveSupport::Dependencies.autoload_paths << ::File.expand_path("lib")

  Dir.glob("app/models/**/*.rb") do |model_path|
    dirname = ::File.dirname(::File.expand_path(model_path))
    ActiveSupport::Dependencies.autoload_paths << dirname if !ActiveSupport::Dependencies.autoload_paths.include?(dirname)

    ::File.basename(model_path, ".rb").classify.constantize
  end

  if ENV["SHAPADO_LOAD_ROUTES"]
    puts ">> Loading routes..."
    Devise.warden_config = Warden::Config.new
    Rails.application.routes_reloader.paths << Rails.root+"config/routes.rb"
    Rails.application.routes_reloader.execute_if_updated
    Rails.application.reload_routes!
  end
end
