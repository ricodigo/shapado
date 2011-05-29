class Share
  include Mongoid::Document

  identity :type => String
  field :fb_app_id, :type => String
  field :fb_secret_key, :type => String
  field :fb_active, :type => Boolean, :default => false

  field :starts_with, :type => String
  field :ends_with, :type => String

  field :enable_twitter, :type => Boolean, :default => false
  field :twitter_user, :type => String
  field :twitter_pattern, :type => String

  embedded_in :group, :inverse_of => :share
end
