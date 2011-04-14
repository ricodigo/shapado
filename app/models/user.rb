require 'digest/sha1'

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include MultiauthSupport
  include MongoidExt::Storage
  include Shapado::Models::GeoCommon

  devise :database_authenticatable, :recoverable, :registerable, :rememberable,
         :lockable, :token_authenticatable, :encryptable, :trackable, :omniauthable, :encryptor => :restful_authentication_sha1

  ROLES = %w[user moderator admin]
  LANGUAGE_FILTERS = %w[any user] + AVAILABLE_LANGUAGES
  LOGGED_OUT_LANGUAGE_FILTERS = %w[any] + AVAILABLE_LANGUAGES

  identity :type => String
  field :login,                     :type => String, :limit => 40, :index => true
  field :name,                      :type => String, :limit => 100, :default => '', :null => true

  field :bio,                       :type => String, :limit => 200
  field :website,                   :type => String, :limit => 200
  field :location,                  :type => String, :limit => 200
  field :birthday,                  :type => Time

  field :identity_url,              :type => String
  index :identity_url

  field :role,                      :type => String, :default => "user"
  field :last_logged_at,            :type => Time

  field :preferred_languages,       :type => Array, :default => []

  field :language,                  :type => String, :default => "ru"
  index :language
  field :timezone,                  :type => String
  field :language_filter,           :type => String, :default => "user", :in => LANGUAGE_FILTERS

  field :ip,                        :type => String
  field :country_code,              :type => String
  field :country_name,              :type => String, :default => "unknown"
  field :hide_country,              :type => Boolean, :default => false

  field :default_subtab,            :type => Hash, :default => {}

  field :followers_count,           :type => Integer, :default => 0
  field :following_count,           :type => Integer, :default => 0

  field :membership_list,           :type => MembershipList

  field :feed_token,                :type => String, :default => lambda { BSON::ObjectId.new.to_s }
  field :socket_key,                :type => String, :default => lambda { BSON::ObjectId.new.to_s }

  field :anonymous,                 :type => Boolean, :default => false
  index :anonymous

  field :friend_list_id, :type => String
  embeds_one :notification_opts, :class_name => "NotificationConfig"

  file_key :avatar, :max_length => 1.megabytes
  field :use_gravatar, :type => Boolean, :default => true
  file_list :thumbnails

  referenced_in :friend_list

  references_many :questions, :dependent => :destroy
  references_many :answers, :dependent => :destroy
  references_many :badges, :dependent => :destroy
  references_many :searches, :dependent => :destroy
  references_many :invitations, :dependent => :destroy
  references_one :facebook_friends_list, :dependent => :destroy
  references_one :twitter_friends_list, :dependent => :destroy
  references_one :identica_friends_list, :dependent => :destroy
  references_one :linked_in_friends_list, :dependent => :destroy

  before_create :initialize_fields
  after_create :create_friends_lists

  before_create :generate_uuid
  after_create :update_anonymous_user

  validates_inclusion_of :language, :in => AVAILABLE_LOCALES
  validates_inclusion_of :role,  :in => ROLES

  with_options :if => lambda { |e| !e.anonymous } do |v|
    v.validates_presence_of     :login
    v.validates_length_of       :login,    :in => 3..40
    v.validates_uniqueness_of   :login
    v.validates_format_of       :login,    :with => /\w+/
  end

  validates_length_of       :name,     :maximum => 100

  validates_presence_of     :email,    :if => lambda { |e| !e.openid_login? && !e.twitter_login? }
  validates_uniqueness_of   :email,    :if => lambda { |e| e.anonymous || (!e.openid_login? && !e.twitter_login?) }
  validates_length_of       :email,    :in => 6..100, :allow_nil => true, :if => lambda { |e| !e.email.blank? }

  with_options :if => :password_required? do |v|
    v.validates_presence_of     :password
    v.validates_confirmation_of :password
    v.validates_length_of       :password, :in => 6..20, :allow_blank => true
  end

  before_save :update_languages
  before_create :logged!

  def self.find_for_authentication(conditions={})
    where(conditions).first || where(:login => conditions[:email]).first
  end

  def membership_list
    m = self[:membership_list]

    if m.nil?
      m = self[:membership_list] = MembershipList.new
    elsif !m.kind_of?(MembershipList)
      m = self[:membership_list] = MembershipList[m]
    end
    m
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end

  def self.find_by_login_or_id(login, conds = {})
    where(conds.merge(:login => login)).first || where(conds.merge(:_id => login)).first
  end

  def self.find_experts(tags, langs = AVAILABLE_LANGUAGES, options = {})
    opts = {}

    if except = options[:except]
      except = [except] unless except.is_a?(Array)
      opts[:user_id] = {:$nin => except}
    end

    user_ids = UserStat.only(:user_id).where(opts.merge({:answer_tags => {:$in => tags}})).all.map(&:user_id)

    conditions = {:"notification_opts.give_advice" => {:$in => ["1", true]},
                  :preferred_languages.in => langs,
                  :_id.in => user_ids}

    if group_id = options[:group_id]
      conditions[:"membership_list.#{group_id}"] = {:$exists => true}
    end

    User.only([:email, :login, :name, :language]).where(conditions)
  end

  def to_param
    if self.login.blank? || !self.login.match(/^\w[\w\s]*$/)
      self.id
    else
      self.login
    end
  end

  def add_preferred_tags(t, group)
    if t.kind_of?(String)
      t = t.split(",").map{|e| e.strip}
    end

    self.collection.update({:_id => self._id},
                           {:$addToSet => {"membership_list.#{group.id}.preferred_tags" => {:$each => t.uniq}}})
  end

  def remove_preferred_tags(t, group)
    if t.kind_of?(String)
      t = t.split(",").join(" ").split(" ")
    end
    self.class.pull_all({:_id => self._id}, {"membership_list.#{group.id}.preferred_tags" => t})
  end

  def preferred_tags_on(group)
    @group_preferred_tags ||= (config_for(group, false).preferred_tags || []).to_a
  end

  def update_language_filter(filter)
    if LANGUAGE_FILTERS.include? filter
      User.set({:_id => self.id}, {:language_filter => filter})
      true
    else
      false
    end
  end

  def languages_to_filter
    @languages_to_filter ||= begin
      languages = nil
      case self.language_filter
      when "any"
        languages = AVAILABLE_LANGUAGES
      when "user"
        languages = (self.preferred_languages.empty?) ? AVAILABLE_LANGUAGES : self.preferred_languages
      else
        languages = [self.language_filter]
      end
      languages
    end
  end

  def is_preferred_tag?(group, *tags)
    ptags = config_for(group, false).preferred_tags
    tags.detect { |t| ptags.include?(t) } if ptags
  end

  def admin?
    self.role == "admin"
  end

  def age
    return if self.birthday.blank?

    Time.zone.now.year - self.birthday.year - (self.birthday.to_time.change(:year => Time.zone.now.year) >
Time.zone.now ? 1 : 0)
  end

  def can_modify?(model)
    return false unless model.respond_to?(:user)
    self.admin? || self == model.user
  end

  def can_create_reward?(question)
    (Time.now - question.created_at) >= 2.days && config_for(question.group_id).reputation >= 75 && (question.reward.nil? || !question.reward.active)
  end

  def groups(options = {})
    self.membership_list.groups(options).order_by([:activity_rate, :desc])
  end

  def member_of?(group)
    if group.kind_of?(Group)
      group = group.id
    end

    self.membership_list.has_key?(group)
  end

  def role_on(group)
    config_for(group, false).role
  end

  def owner_of?(group)
    admin? || group.owner_id == self.id || role_on(group) == "owner"
  end

  def admin_of?(group)
    role_on(group) == "admin" || owner_of?(group)
  end

  def mod_of?(group)
    owner_of?(group) || role_on(group) == "moderator" || self.reputation_on(group) >= group.reputation_constrains["moderate"].to_i
  end

  def editor_of?(group)
    if c = config_for(group, false)
      c.is_editor
    else
      false
    end
  end

  def user_of?(group)
    mod_of?(group) || self.membership_list.has_key?(group.id)
  end

  def main_language
    @main_language ||= self.language.split("-").first
  end

  def openid_login?
    !self.auth_keys.blank? || (AppConfig.enable_facebook_auth && !facebook_id.blank?)
  end

  def linked_in_login?
    user_info && !user_info["linked_in"].blank?
  end

  def identica_login?
    user_info && !user_info["identica"].blank?
  end

  def twitter_login?
    user_info && !user_info["twitter"].blank?
  end

  def facebook_login?
    !facebook_id.blank?
  end

  def has_voted?(voteable)
    !vote_on(voteable).nil?
  end

  def vote_on(voteable)
    voteable.votes[self.id] if voteable.votes
  end

  def favorites(opts = {})
    Answer.where(opts.merge(:favoriter_ids => id))
  end

  def logged!(group = nil)
    now = Time.zone.now

    if new_record?
      self.last_logged_at = now
    elsif group && (member_of?(group) || !group.private)
      on_activity(:login, group)
    end
  end

  def on_activity(activity, group)
    if activity == :login
      self.last_logged_at ||= Time.now
      if !self.last_logged_at.today?
        self.override( {:last_logged_at => Time.zone.now.utc} )
      end
    else
      self.update_reputation(activity, group) if activity != :login
    end
    activity_on(group, Time.zone.now)
  end

  def activity_on(group, date)
    day = date.utc.at_beginning_of_day
    last_day = config_for(group, false).last_activity_at

    if last_day != day
      self.override({"membership_list.#{group.id}.last_activity_at" => day})
      if last_day
        if last_day.utc.between?(day.yesterday - 12.hours, day.tomorrow)
          self.increment({"membership_list.#{group.id}.activity_days" => 1})

          Jobs::Activities.async.on_activity(group.id, self.id).commit!
        elsif !last_day.utc.today? && (last_day.utc != Time.now.utc.yesterday)
          Rails.logger.info ">> Resetting act days!! last known day: #{last_day}"
          reset_activity_days!(group)
        end
      end
    end
  end

  def reset_activity_days!(group)
    self.override({"membership_list.#{group.id}.activity_days" => 0})
  end

  def upvote!(group, v = 1.0)
    self.increment({"membership_list.#{group.id}.votes_up" => v.to_f})
  end

  def downvote!(group, v = 1.0)
    self.increment({"membership_list.#{group.id}.votes_down" => v.to_f})
  end

  def update_reputation(key, group, v = nil)
    if v.nil?
      value = group.reputation_rewards[key.to_s].to_i
      value = key if key.kind_of?(Integer)
    else
      value = v
    end

    Rails.logger.info "#{self.login} received #{value} points of karma by #{key} on #{group.name}"
    current_reputation = config_for(group, false).reputation

    if value
      self.increment(:"membership_list.#{group.id}.reputation" =>  value)
    end

    stats = self.reputation_stats(group)
    stats.save if stats.new?

    event = ReputationEvent.new(:time => Time.now, :event => key,
                                :reputation => current_reputation,
                                :delta => value )
    ReputationStat.collection.update({:_id => stats.id}, {:$addToSet => {:events => event.attributes}})
  end

  def reputation_on(group)
    config_for(group, false).reputation.to_i
  end

  def stats(*extra_fields)
    fields = [:_id]

    UserStat.only(fields+extra_fields).where(:user_id => self.id).first || UserStat.create(:user_id => self.id)
  end

  def badges_count_on(group)
    config = config_for(group, false)
    [config.bronze_badges_count, config.silver_badges_count, config.gold_badges_count]
  end

  def badges_on(group, opts = {})
    self.badges.where(opts.merge(:group_id => group.id)).order_by(:created_at.desc)
  end

  def find_badge_on(group, token, opts = {})
    self.badges.where(opts.merge(:token => token, :group_id => group.id)).first
  end

  # self follows user
  def add_friend(user)
    return false if user == self
    FriendList.collection.update({ "_id" => self.friend_list_id}, { "$addToSet" => { :following_ids => user.id } })
    FriendList.collection.update({ "_id" => user.friend_list_id}, { "$addToSet" => { :follower_ids => self.id } })

    self.inc(:following_count, 1)
    user.inc(:followers_count, 1)
    true
  end

  def remove_friend(user)
    return false if user == self
    FriendList.collection.update({ "_id" => self.friend_list_id}, { "$pull" => { :following_ids => user.id } })
    FriendList.collection.update({ "_id" => user.friend_list_id}, { "$pull" => { :follower_ids => self.id } })

    self.inc(:following_count, -1)
    user.inc(:followers_count, -1)
    true
  end

  def followers(scope = {})
    conditions = {}
    conditions[:preferred_languages] = {:$in => scope[:languages]}  if scope[:languages]
    conditions[:"membership_list.#{scope[:group_id]}"] = {:$exists => true} if scope[:group_id]
    self.friend_list.followers.where(conditions)
  end

  def following
    self.friend_list.following
  end

  def following?(user)
    FriendList.only(:following_ids).where(:_id => self.friend_list_id).first.following_ids.include?(user.id)
  end

  def viewed_on!(group)
    self.increment("membership_list.#{group.id}.views_count" => 1.0)
  end

  def method_missing(method, *args, &block)
    if !args.empty? && method.to_s =~ /can_(\w*)\_on?/
      key = $1
      group = args.first
      if group.reputation_constrains.include?(key.to_s)
        if group.has_reputation_constrains
          return self.owner_of?(group) || self.mod_of?(group) || (self.reputation_on(group) >= group.reputation_constrains[key].to_i)
        else
          return true
        end
      end
    end
    super(method, *args, &block)
  end

  def config_for(group, init = false)
    if group.kind_of?(Group)
      group = group.id
    end

    config = self.membership_list.get(group)
    if config.nil?
      if init
        config = self.membership_list[group] = Membership.new(:group_id => group)
      else
        config = Membership.new(:group_id => group)
      end
    end
    config
  end

  def reputation_stats(group, options = {})
    if group.kind_of?(Group)
      group = group.id
    end
    default_options = { :user_id => self.id,
                        :group_id => group}
    stats = ReputationStat.where(default_options.merge(options)).first ||
            ReputationStat.new(default_options)
  end

  def has_flagged?(flaggeable)
    flaggeable.flags.detect do |flag|
      flag.user_id == self.id
    end
  end

  def has_requested_to_close?(question)
    question.close_requests.detect do |close_request|
      close_request.user_id == self.id
    end
  end

  def has_requested_to_open?(question)
    question.open_requests.detect do |open_request|
      open_request.user_id == self.id
    end
  end

  def generate_uuid
    self.feed_token = UUIDTools::UUID.random_create.hexdigest
  end

  def self.find_file_from_params(params, request)
    if request.path =~ %r{/(avatar|big|medium|small)/([^/\.\?]+)}
      @user = User.find($2)
      case $1
      when "avatar"
        @user.avatar
      when "big"
        @user.thumbnails["big"] ? @user.thumbnails.get("big") : @user.avatar
      when "medium"
        @user.thumbnails["medium"] ? @user.thumbnails.get("medium") : @user.avatar
      when "small"
        @user.thumbnails["small"] ? @user.thumbnails.get("small") : @user.avatar
      end
    end
  end

  def facebook_friends
    self.facebook_friends_list.friends
  end

  def fb_friends_ids
    self.facebook_friends.map do |friend| friend["id"] end
  end

  def twitter_friends
    self.twitter_friends_list.friends
  end
  alias :twitter_friends_ids :twitter_friends

  def identica_friends
    self.identica_friends_list.friends
  end
  alias :identica_friends_ids :identica_friends

  def linked_in_friends
    self.linked_in_friends_list.friends
  end
  alias :linked_in_friends_ids :linked_in_friends

  ## TODO: add google contacts
  def suggestions(group, limit = 5)
    sample = (suggested_fb_friends(limit) | suggested_twitter_friends(limit) |
              suggested_identica_friends(limit) | suggested_linked_in_friends(limit) |
              suggested_tags(group, limit) | suggested_tags_by_suggested_friends(group, limit) ).sample(limit)

    # if we find less suggestions than requested, complete with
    # most popular users and tags
    (sample.size < limit) ? sample |
      (group.top_tags_strings(limit+15)-self.preferred_tags_on(group) + group.top_users(limit+5)-[self]).
      sample(limit-sample.size) : sample
  end

  # returns tags followed by my friends but not by self
  # TODO: optimize
  def suggested_tags(group, limit = 5)
    friends = User.where("membership_list.#{group.id}.preferred_tags" => {"$ne" => [], "$ne" => nil},
                         "_id" => { "$in" => self.friend_list.following_ids}).
                         only("membership_list.#{group.id}.preferred_tags", "login", "name")
    friends_tags = { }
    friends.each do |friend|
      (friend.membership_list[group.id]["preferred_tags"]-self.preferred_tags_on(group)).each do |tag|
        friends_tags["#{tag}"] ||= { }
        friends_tags["#{tag}"]["followed_by"] ||= []
        friends_tags["#{tag}"]["followed_by"] << friend
      end
    end
     friends_tags.to_a.sample(limit)
  end

  #returns tags followed by self suggested friends that I may not follow
  def suggested_tags_by_suggested_friends(group, limit = 5)
    friends = User.any_of({ :facebook_id => {:$in => self.fb_friends_ids}},
                          { :identica_id => {:$in => self.identica_friends_ids}},
                          { :twitter_id => {:$in => self.twitter_friends_ids}},
                          { :linked_in_id => {:$in => self.linked_in_friends_ids}}).
      where("membership_list.#{group.id}.preferred_tags" => {"$ne" => [], "$ne" => nil},
            :_id => {:$not =>
              {:$in => self.friend_list.following_ids}})
    friends_tags = { }
    friends.each do |friend|
      (friend.membership_list[group.id]["preferred_tags"]-self.preferred_tags_on(group)).each do |tag|
        friends_tags["#{tag}"] ||= { }
        friends_tags["#{tag}"]["followed_by"] ||= []
        friends_tags["#{tag}"]["followed_by"] << friend
      end
    end
     friends_tags.to_a.sample(limit)
  end

  # returns user's facebook friends that have an account
  # on shapado but that user is not following
  def suggested_fb_friends(limit = 5)
    User.where(:facebook_id => {:$in => self.fb_friends_ids},
               :_id => {:$not =>
                 {:$in => self.friend_list.following_ids}}).
      limit(limit)
  end

  # returns user's twitter friends that have an account
  # on shapado but that user is not following
  def suggested_twitter_friends(limit = 5)
    User.where(:twitter_id => {:$in => self.twitter_friends_ids},
               :_id => {:$not =>
                 {:$in => self.friend_list.following_ids}}).
      limit(limit)
  end

  # returns user's identica friends that have an account
  # on shapado but that user is not following
  def suggested_identica_friends(limit = 5)
    User.where(:identica_id => {:$in => self.identica_friends_ids},
               :_id => {:$not =>
                 {:$in => self.friend_list.following_ids}}).
      limit(limit)
  end

  # returns user's linked_in friends that have an account
  # on shapado but that user is not following
  def suggested_linked_in_friends(limit = 5)
    User.where(:linked_in_id => {:$in => self.linked_in_friends_ids},
               :_id => {:$not =>
                 {:$in => self.friend_list.following_ids}}).
      limit(limit)
  end

  # returns all user's facebook friends on shapado
  def all_fb_friends
    User.where(:facebook_id => {:$in => self.fb_friends_ids})
  end

  # returns a follower that is someone self follows
  # if @user follows bob and bob follows bill
  # @user.common_follower(bill) will return bob
  def common_follower(user)
    User.where(:_id => (self.friend_list.following_ids & user.friend_list.follower_ids).sample).first
  end

  def invite(email, group)
    if self.can_invite_on?(group)
      Invitation.create(:user_id => self.id,
                        :email => email,
                        :group_id => group.id)
    end
  end

  def revoke_invite(invitation)
    invite.destroy if self.can_modify?(invitation)
  end

  def can_invite_on?(group)
    return true if self.admin_of?(group) || self.role == 'admin' ||
      group.invitations_perms == 'user' ||
      (group.invitations_perms == 'moderator' &&
       self.mod_of?(group))
    return false
  end

  def accept_invitation(invitation_id)
    invitation = Invitation.find(invitation_id)
    group = invitation.group
    invitation.update(:accepted => true) &&
      group.add_member(self, 'user')
  end

  protected
  def update_languages
    self.preferred_languages = self.preferred_languages.map { |e| e.split("-").first }
  end

  def password_required?
    return false if openid_login? || twitter_login? || self.anonymous

    (encrypted_password.blank? || !password.blank?)
  end

  def initialize_fields
    self.friend_list = FriendList.create if self.friend_list.nil?
    self.notification_opts = NotificationConfig.new if self.notification_opts.nil?
  end

  def update_anonymous_user
    return if self.anonymous

    user = User.where({:email => self.email, :anonymous => true}).first
    if user.present?
      Rails.logger.info "Merging #{self.email}(#{self.id}) into #{user.email}(#{user.id})"
      merge_user(user)
      self.membership_list = user.membership_list

      user.destroy
    end
  end

  def create_friends_lists
    facebook_friend_list = FacebookFriendsList.create
    self.facebook_friends_list = facebook_friend_list

    twitter_friend_list = TwitterFriendsList.create
    self.twitter_friends_list = twitter_friend_list

    identica_friend_list = IdenticaFriendsList.create
    self.identica_friends_list = identica_friend_list

    linked_in_friend_list = LinkedInFriendsList.create
    self.linked_in_friends_list = linked_in_friend_list
  end
end
