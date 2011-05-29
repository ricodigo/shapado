class Membership < EmbeddedHash
  ROLES = %w[user moderator owner]

  field :display_name, :type => String

  field :group_id, :type => String

  field :reputation, :type => Float, :default => 0.0

  field :profile, :type => Hash, :default => {} # custom user keys

  field :votes_up, :type => Float, :default => 0.0
  field :votes_down, :type => Float, :default => 0.0

  field :views_count, :type => Float, :default => 0.0

  field :preferred_tags, :type => Array, :default => []

  field :last_activity_at, :type => Time
  field :activity_days, :type => Integer, :default => 0

  field :role, :type => String, :default => "user"

  field :bronze_badges_count,       :type => Integer, :default => 0
  field :silver_badges_count,       :type => Integer, :default => 0
  field :gold_badges_count,         :type => Integer, :default => 0
  field :is_editor,                 :type => Boolean, :default => false

  field :comments_count,            :type => Integer, :default => 0

  validates_inclusion_of :role,  :in => ROLES
end
