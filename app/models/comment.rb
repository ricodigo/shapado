class Comment
  include Mongoid::Document
  include Support::Voteable
  include Mongoid::Timestamps

#   include Shapado::Models::GeoCommon FIXME


  identity :type => String

  field :body, :type =>  String
  field :language, :type =>  String, :default => "en"
  field :banned, :type =>  Boolean, :default => false

  field :position, :type =>  GeoPosition, :default => GeoPosition.new(0, 0) # FIXME

  field :user_id, :type => String
  referenced_in :user

  embedded_in :commentable, :inverse_of => :comments

  validates_presence_of :body
  validates_presence_of :user

  def group
    self._parent.group
  end

  def commentable_type
    self._parent.class.to_s
  end

  def can_be_deleted_by?(user)
    ok = (self.user_id == user.id && user.can_delete_own_comments_on?(self.group)) || user.mod_of?(self.group)
    if !ok && user.can_delete_comments_on_own_questions_on?(self.group) && (q = self.find_question)
      ok = (q.user_id == user.id)
    end

    ok
  end

  def find_question
    question = nil
    commentable = self._parent
    if commentable.kind_of?(Question)
      question = commentable
    elsif commentable.respond_to?(:question)
      question = commentable.question
    end

    question
  end

  def question_id
    question_id = nil

    if self.commentable.is_a?(Question)
      question_id = self.commentable.id
    elsif self.commentable.is_a?(Answer)
      question_id = self.commentable.question_id
    elsif self.commentable.respond_to?(:question)
      question_id = self.commentable.question_id
    end

    question_id
  end

  def find_recipient
    if self.commentable.respond_to?(:user)
      self.commentable.user
    end
  end
end
