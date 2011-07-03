require 'compass'
# If you have any compass plugins, require them here.
Compass.add_project_configuration(File.join(Rails.root, "config", "compass.config"))
Compass.configuration.environment = ENV['debug_assets'] ? :development : Rails.env.to_sym
Compass.configure_sass_plugin!
