class DynamicDomain
  def initialize(app)
    @app = app
  end

  def call(env)
    host = env["HTTP_HOST"].split(':').first
    if custom_domain?(host)
      ActionMailer::Base.default_url_options[:host] = host
    else
      ActionMailer::Base.default_url_options[:host] = AppConfig.domain
      host = ".#{AppConfig.domain}"
    end

    env["rack.session.options"][:domain] = host

    @app.call(env||{})
  end

  def custom_domain?(host)
    host !~ Regexp.new("#{AppConfig.domain}$", Regexp::IGNORECASE)
  end
end

