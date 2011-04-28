class Invitation
  include Mongoid::Document
  include Mongoid::Timestamps

  identity :type => String
  field :token, :type => String
  index :token
  field :email, :type => String
  index :email
  field :accepted, :type => Boolean, :default => false
  field :state, :type => String, :default => "pending"
  field :accepted_by, :type => String
  field :accepted_at, :type => Time
  field :user_role, :type => String, :default => "user"
  referenced_in :group
  referenced_in :user

  before_create :generate_token

  validates_uniqueness_of :user_id, :scope => [:group_id, :email]
  validates_inclusion_of :user_role,  :in => Membership::ROLES

  state_machine :state, :initial => :pending do
    after_transition :on => :connect, :do => :on_connected
    after_transition :on => :confirm, :do => :on_confirmed
    after_transition :on => :find_friends, :do => :on_found_friends
    after_transition :on => :follow_suggestions, :do => :on_followed_suggestions
    event :connect do
      transition :pending => :connect, :if => :check_connection
    end
    event :confirm do
      transition :connect => :confirm
    end
    event :find_friends do
      transition :confirm => :find_friends, :if => :check_confirm
    end
    event :follow_suggestions do
      transition :find_friends => :follow_suggestions, :if => :check_confirm
    end
  end

  def check_confirm
    !state?(:pending) && !state?(:connected)
  end

  def check_connection
    user = User.find(accepted_by)
    user && (user.is_socially_connected? || !self.group.is_social_only_signup?)
  end

  def on_connected
    if self.group.is_noemail_signup?
      self.confirm
    end
  end

  def on_confirmed
    if self.group.is_email_only_signup?
      self.on_followed_suggestions
    end
  end

  def on_found_friends
  end

  def on_followed_suggestions
  end

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
