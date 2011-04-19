class Invitation
  include Mongoid::Document
  include Mongoid::Timestamps

  identity :type => String
  field :token, :type => String
  index :token
  field :email, :type => String
  index :email
  field :accepted, :type => Boolean, :default => false
  field :accepted_by, :type => String
  field :accepted_at, :type => Time
  field :user_role, :type => String, :default => "user"
  referenced_in :group
  referenced_in :user

  before_create :generate_token

  validates_uniqueness_of :user_id, :scope => [:group_id, :email]
  validates_inclusion_of :user_role,  :in => Membership::ROLES

  def accepted_by_other?(user)
    return true if !user.nil? && !self.accepted_by.nil? &&
      self.accepted_by != user.id
    return false
  end

  protected
  def generate_token
    self.token = UUIDTools::UUID.random_create.hexdigest
  end
end
