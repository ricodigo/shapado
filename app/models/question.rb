class Question
  include Mongoid::Document
  include Mongoid::Timestamps

  include MongoidExt::Filter
  include MongoidExt::Slugizer
  include MongoidExt::Tags
  include MongoidExt::Random
  include MongoidExt::Storage

  include Support::Versionable
  include Support::Voteable
  include Shapado::Models::GeoCommon
  include Shapado::Models::Trackable

  track_activities :user, :title, :language, :scope => [:group_id]

  index :tags

  identity :type => String

  field :title, :type => String, :default => ""
  field :body, :type => String
  slug_key :title, :unique => true, :min_length => 8
  field :slugs, :type => Array
  index :slugs

  field :answers_count, :type => Integer, :default => 0
  field :views_count, :type => Integer, :default => 0
  field :hotness, :type => Integer, :default => 0
  field :flags_count, :type => Integer, :default => 0
  field :close_requests_count, :type => Integer, :default => 0
  field :open_requests_count, :type => Integer, :default => 0

  field :adult_content, :type => Boolean, :default => false
  field :banned, :type => Boolean, :default => false
  index :banned
  field :accepted, :type => Boolean, :default => false
  field :closed, :type => Boolean, :default => false
  field :closed_at, :type => Time

  field :anonymous, :type => Boolean, :default => false
  index :anonymous

  field :answered_with_id, :type => String
  referenced_in :answered_with, :class_name => "Answer"

  field :wiki, :type => Boolean, :default => false
  field :subjetive, :type => Boolean, :default => false
  field :language, :type => String, :default => "en"
  index :language

  field :activity_at, :type => Time

  field :short_url, :type => String

  referenced_in :user
  index :user_id

  field :answer_id, :type => String
  referenced_in :answer

  referenced_in :group
  index :group_id

  field :followers_count, :type => Integer, :default => 0
  references_and_referenced_in_many :followers, :class_name => "User"

  field :contributors_count, :type => Integer, :default => 0
  references_and_referenced_in_many :contributors, :class_name => "User"

  field :updated_by_id, :type => String
  referenced_in :updated_by, :class_name => "User"

  field :close_reason_id, :type => String

  field :last_target_type, :type => String
  field :last_target_id, :type => String
  field :last_target_date, :type => Time

  file_list :attachments

  attr_accessor :removed_tags

#   referenced_in :last_target, :polymorphic => true

  field :last_target_user_id, :type => String
  referenced_in :last_target_user, :class_name => "User"

  references_many :answers, :dependent => :destroy
  references_many :badges, :as => "source", :validate => false

  embeds_many :comments, :as => "commentable"#, :order => "created_at asc"
  embeds_many :flags, :as => "flaggable"
  embeds_many :close_requests, :as => "closeable"
  embeds_many :open_requests, :as => "openable"

  embeds_one :follow_up
  embeds_one :reward

  validates_presence_of :title
  validates_presence_of :user
  validates_uniqueness_of :slug, :scope => "group_id", :allow_blank => true

  validates_length_of       :title,    :in => 5..100, :wrong_length => lambda { I18n.t("questions.model.messages.title_too_long") }
  validates_length_of       :body,     :minimum => 5, :allow_blank => true #, :if => lambda { |q| !q.disable_limits? }

#  FIXME mongoid (create a validator for tags size)
#   validates_true_for :tags, :logic => lambda { |q| q.tags.size <= 9},
#                      :message => lambda { |q| I18n.t("questions.model.messages.too_many_tags") if q.tags.size > 9 }

  versionable_keys :title, :body, :tags
  filterable_keys :title, :body
  language :language

  before_save :update_activity_at
  validate :update_language, :on => :create

  validates_inclusion_of :language, :in => AVAILABLE_LANGUAGES, :if => lambda {AppConfig.enable_i18n}

  validate :group_language
  validate :disallow_spam
  validate :check_useful

  def self.minimal
    without(:_keywords, :close_requests, :open_requests, :versions)
  end

  def followed_up_by
    Question.minimal.without(:comments).where(:"follow_up.original_question_id" => self.id)
  end

  def email
    "#{AppConfig.mailing["user"]}+#{self.group.subdomain}-#{self.id}@#{self.group.domain}"
  end

  def first_tags
    tags[0..5]
  end

  def tags=(t)
    if t.kind_of?(String)
      t = t.downcase.split(/[,\+\s]+/).uniq
    end

    if self.user && !self.user.can_create_new_tags_on?(self.group)
      tmp_tags = self.group.tags.where(:name.in => t).only(:name).map(&:name)
      self.removed_tags = t-tmp_tags
      t = tmp_tags
    end

    self[:tags] = t
  end

  def self.related_questions(question, opts = {})
    opts[:group_id] = question.group_id
    opts[:banned] = false

    Question.where(opts.merge(:_keywords.in => question.tags, :_id.ne => question.id))
  end

  def viewed!(ip)
    view_count_id = "#{self.id}-#{ip}"
    if ViewsCount.where({:_id => view_count_id}).first.nil?
      ViewsCount.create(:_id => view_count_id)
      self.inc(:views_count, 1)
    end
  end

  def answer_added!
    self.inc(:answers_count, 1)
    on_activity
  end

  def answer_removed!
    self.decrement(:answers_count => 1)
  end

  def flagged!
    self.inc(:flags_count, 1)
  end

  def on_add_vote(v, voter)
    if v > 0
      self.user.update_reputation(:question_receives_up_vote, self.group)
      voter.on_activity(:vote_up_question, self.group)
    else
      self.user.update_reputation(:question_receives_down_vote, self.group)
      voter.on_activity(:vote_down_question, self.group)
    end
    on_activity(false)
  end

  def on_remove_vote(v, voter)
    if v > 0
      self.user.update_reputation(:question_undo_up_vote, self.group)
      voter.on_activity(:undo_vote_up_question, self.group)
    else
      self.user.update_reputation(:question_undo_down_vote, self.group)
      voter.on_activity(:undo_vote_down_question, self.group)
    end
    on_activity(false)
  end

  def on_activity(bring_to_front = true)
    update_activity_at if bring_to_front
    self.inc(:hotness, 1)
  end

  def update_activity_at
    self[:subjetive] = self.tags.include?(I18n.t("global.subjetive", :default =>
"subjetive"))

    now = Time.now
    if new_record?
      self.activity_at = now
    else
      self.override(:activity_at => now)
    end
  end

  def ban
    self.override(:banned => true)
  end

  def self.ban(ids, options = {})
    self.override({:_id => {"$in" => ids}}.merge(options), {:banned => true})
  end

  def unban
    self.override(:banned => false)
  end

  def self.unban(ids, options = {})
    self.override({:_id => {"$in" => ids}}.merge(options), {:banned => false})
  end

  def add_follower(user)
    if !follower?(user)
      self.push_uniq(:follower_ids => user.id)
      self.increment(:followers_count => 1)
    end
  end

  def remove_follower(user)
    if follower?(user)
      self.pull(:follower_ids => user.id)
      self.decrement(:followers_count => 1)
    end
  end

  def follower?(user)
    self.follower_ids && self.follower_ids.include?(user.id)
  end

  def add_contributor(user)
    if !contributor?(user)
      self.push_uniq(:contributor_ids => user.id)
      self.increment(:contributors_count => 1)
    end
  end

  def remove_contributor(user)
    if contributor?(user)
      self.pull(:contributor_ids => user.id)
      self.decrement(:contributors_count => 1)
    end
  end

  def contributor?(user)
    self.contributor_ids && self.contributor_ids.include?(user.id)
  end

  def disable_limits?
    self.user.present? && self.user.can_post_whithout_limits_on?(self.group)
  end

  def answered
    self.answered_with_id.present?
  end

  def update_last_target(target)
    self.class.update_last_target(self._id, target)
  end

  def self.update_last_target(question_id, target)
    data = {:last_target_id => target.id,
            :last_target_user_id => target.user_id,
            :last_target_type => target.class.to_s}
    if target.respond_to?(:updated_at) && target.updated_at.present?
      data[:last_target_date] = target.updated_at.utc
    end
    self.override({:_id => question_id}, data)
  end

  def can_be_requested_to_close_by?(user)
    return false if self.closed
    ((self.user_id == user.id) && user.can_vote_to_close_own_question_on?(self.group)) ||
    user.can_vote_to_close_any_question_on?(self.group)
  end

  def can_be_requested_to_open_by?(user)
    return false if !self.closed
    ((self.user_id == user.id) && user.can_vote_to_open_own_question_on?(self.group)) ||
    user.can_vote_to_open_any_question_on?(self.group)
  end

  def can_be_deleted_by?(user)
    (self.user_id == user.id && self.answers.count < 1) ||
    (self.closed && user.can_delete_closed_questions_on?(self.group))
  end

  def close_reason
    self.close_requests.detect{ |rq| rq.id == close_reason_id }
  end

  def last_target=(target)
    self.last_target_id = target.id
    self.last_target_type = target.class.to_s
    self.last_target_date = target.updated_at
    self.last_target_user_id = target.user_id
  end

  def attachments=(files)
    files.each do |k,v|
      if(v.size > 0)
        self.attachments.put(BSON::ObjectId.new.to_s, v)
      end
    end
  end

  def self.find_file_from_params(params, request)
    if request.path =~ /\/(attachment)\/([^\/\.?]+)\/([^\/\.?]+)\/([^\/\.?]+)/
      @group = Group.by_slug($2)
      @question = @group.questions.find($3)
      case $1
      when "attachment"
        @question.attachments.get($4)
      end
    end
  end

  def self.humanize_action(action)
    case action
    when "create"
      "asked"
    when "update"
      "changed"
    when "destroy"
      "deleted"
    end
  end

  protected
  def self.map_filter_operators(quotes, ops)
    mongoquery = {}
    if !quotes.empty?
      q = {:$in => quotes.map { |quote| /#{Regexp.escape(quote)}/i }}
      mongoquery[:$or] = [{:title => q}, {:body => q}]
    end

    if ops["is"]
      ops["is"].each do |d|
        case d
        when "answered"
          mongoquery[:answered] = true
        when "accepted"
          mongoquery[:accepted] = true
        end
      end
    end

    if ops["not"]
      ops["not"].each do |d|
        case d
        when "answered"
          mongoquery[:answered] = false
        when "accepted"
          mongoquery[:accepted] = false
        end
      end
    end

    if ops["lang"]
      mongoquery["language"] = {:$in => ops["lang"].map{|l| /#{l}/ }}
    end

    mongoquery
  end

  def update_answer_count
    self.answers_count = self.answers.count
    votes_average = 0
    self.votes.each {|e| votes_average+=e.value }
    self.votes_average = votes_average

    self.votes_count = self.votes.count
  end

  def update_language
    self.language = self.language.split("-").first
  end

  def group_language
    if self.group.present? && (!self.group.language.nil? && self.group.language != self.language)
      self.errors.add :language, I18n.t("questions.model.messages.not_group_languages")
    end
  end

  def check_useful
    unless disable_limits?
      if !self.title.blank? && self.title.gsub(/[^\x00-\x7F]/, "").size < 5
        return
      end

      if !self.title.blank? && (self.title.split.count < 4)
        self.errors.add(:title, I18n.t("questions.model.messages.too_short", :count => 4))
      end

      if !self.body.blank? && (self.body.split.count < 4)
        self.errors.add(:body, I18n.t("questions.model.messages.too_short", :count => 3))
      end
    end
  end

  def disallow_spam
    if self.new_record? && !disable_limits?
      last_question = Question.where(:user_id => self.user_id,
                                     :group_id => self.group_id).
                                          order_by(:created_at.desc).first

      valid = (last_question.nil? || (Time.now - last_question.created_at) > 20)
      if !valid
        self.errors.add(:body, "you need to wait 20 senconds before posting another question.") # TODO i18n
      end
    end
  end
end

