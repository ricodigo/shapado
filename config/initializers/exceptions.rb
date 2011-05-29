class Error404 < Exception
end

if AppConfig.exception_notification['activate'] && Rails.env == "production"
  Shapado::Application.config.middleware.use ExceptionNotifier,
  :email_prefix => "[#{AppConfig.application_name} Exception] ",
  :sender_address => AppConfig.exception_notification['exception_sender_address'],
  :exception_recipients => AppConfig.exception_notification['exception_recipients']
end
