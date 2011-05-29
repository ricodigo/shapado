module Shapado
  module Scripting
    class Application < Rails::Application
      require './config/load_config'

      config.cache_classes = true
      config.encoding = "utf-8"

      if AppConfig.smtp["activate"]
        config.action_mailer.delivery_method = :smtp
      else
        config.action_mailer.delivery_method = :sendmail
      end
      config.action_mailer.default_url_options = {:host => AppConfig.domain}
    end
  end
end

require "smtp_tls"

Rails.application = Shapado::Scripting::Application.instance
ActionController::Base.prepend_view_path "#{Rails.root}/app/views"
ActionMailer::Base.prepend_view_path "#{Rails.root}/app/views"
