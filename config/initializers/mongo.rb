Magent.setup(YAML.load_file(Rails.root.join('config', 'magent.yml')),
                  Rails.env, {})

MongoidExt.init

Dir.glob("#{Rails.root}/app/models/**/*.rb") do |model_path|
  File.basename(model_path, ".rb").classify.constantize
end

Dir.glob("#{Rails.root}/app/javascripts/**/*.js") do |js_path|
  code = File.read(js_path)
  name = File.basename(js_path, ".js")

  # HACK: looks like ruby driver doesn't support this
  Mongoid.database.eval("db.system.js.save({_id: '#{name}', value: #{code}})")
end

require 'support/voteable'

Mongoid.config.raise_not_found_error = false
