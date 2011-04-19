class Flag
  include Mongoid::Document
  include Shapado::Models::Trackable

  track_activities :user, :reason, :flaggable, :scope => [:group_id], :target => :flaggable

  REASONS = ["spam", "offensive", "attention"]

  identity :type => String

  field :reason, :type => String, :required => true, :default => "spam"

  field :user_id, :type => String
  referenced_in :user

  embedded_in :flaggable, :inverse_of => :flags

  validates_presence_of :user
  validates_inclusion_of :reason, :in => REASONS

  validate :should_be_unique
  validate :check_reputation

  protected
  def should_be_unique
    request = self._parent.flags.detect{ |rq| rq.user_id == self.user_id }
    valid = (request.nil? || request.id == self.id)

    if !valid
      self.errors.add(:user, I18n.t("flags.model.messages.already_requested",
                                    :model => I18n.t("activerecord.models.#{@resource.class.to_s.tableize.singularize}")))
    end
    valid
  end

  def check_reputation
    if ((self._parent.user_id == self.user_id) && !self.user.can_flag_on?(self.flaggable.group))
      reputation = self._parent.group.reputation_constrains["flag"]
      self.errors.add(:reputation, I18n.t("users.messages.errors.reputation_needed",
                                          :min_reputation => reputation,
                                          :action => I18n.t("users.actions.flag")))
      return false
    end
    true
  end
end
