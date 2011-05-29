
class CloseRequest
  include Mongoid::Document
  include Shapado::Models::Trackable

  track_activities :user, :reason, :comment, :closeable, :scope => [:group_id], :target => :closeable

  REASONS = %w{dupe ot no_question not_relevant spam}

  identity :type => String
  field :reason, :type => String
  field :comment, :type => String

  referenced_in :user
  embedded_in :closeable, :inverse_of => :close_requests

  validates_presence_of :user
  validates_inclusion_of :reason, :in => REASONS


  validate :should_be_unique
  validate :check_reputation

  def increment_counter
    self.closeable.increment(:close_requests_count => 1)
  end

  def decrement_counter
    self._parent.decrement(:close_requests_count => 1)
  end

  def self.humanize_action(action)
    case action
    when "create"
      "requested_to_close"
    end
  end

  protected
  def should_be_unique
    valid = true
    request = self._parent.close_requests.detect{ |rq| rq.user_id == self.user_id }
    valid = (request.nil? || request.id == self.id)

    unless valid
      self.errors.add(:user, I18n.t("close_requests.model.messages.already_requested"))
    end

    valid
  end

  def check_reputation
    parent = self._parent

    if parent.can_be_requested_to_close_by?(self.user)
      return true
    end

    if ((parent.user_id == self.user_id) &&
        !self.user.can_vote_to_close_own_question_on?(parent.group))
      reputation = parent.group.reputation_constrains["vote_to_close_own_question"]
      self.errors.add(:reputation, I18n.t("users.messages.errors.reputation_needed",
                                          :min_reputation => reputation,
                                          :action => I18n.t("users.actions.vote_to_close_own_question")))
      return false
    end

    unless self.user.can_vote_to_close_any_question_on?(parent.group)
      reputation = parent.group.reputation_constrains["vote_to_close_any_question"]
            self.errors.add(:reputation, I18n.t("users.messages.errors.reputation_needed",
                                          :min_reputation => reputation,
                                          :action => I18n.t("users.actions.vote_to_close_any_question")))
      return false
    end

    true
  end
end
