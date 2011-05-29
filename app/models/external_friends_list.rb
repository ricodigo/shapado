class ExternalFriendsList
  include Mongoid::Document

  identity :type => String
  field :friends, :type => Hash, :default => {}
  referenced_in :user
end
