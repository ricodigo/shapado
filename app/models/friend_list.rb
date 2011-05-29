class FriendList
  include Mongoid::Document

  identity :type => String

  references_one :user

#   field :follower_ids, :type => Array, :default => []
  references_and_referenced_in_many :followers, :class_name => "User", :inverse_class_name => "User"

#   field :following_ids, :type => Array, :default => []
  references_and_referenced_in_many :following, :class_name => "User", :inverse_class_name => "User"
end
