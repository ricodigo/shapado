module MultiauthSupport
  extend ActiveSupport::Concern

  included do
    field :using_openid, :type => Boolean, :default => false
    field :openid_email

    field :twitter_handle, :type => String
    field :twitter_oauth_token, :type => String
    field :twitter_oauth_secret, :type => String

    field :facebook_id,               :type => String
    field :facebook_token,            :type => String
    field :facebook_profile,          :type => String

    field :twitter_token,             :type => String
    field :twitter_secret,            :type => String
    field :twitter_login,             :type => String
    field :twitter_id,                :type => String

    field :identica_token,             :type => String
    field :identica_secret,            :type => String
    field :identica_login,             :type => String
    field :identica_id,                :type => String

    field :linked_in_id,               :type => String
    field :linked_in_token,            :type => String
    field :linked_in_secret,            :type => String

    field :github_id, :type => String
    field :github_login, :type => String

    field :auth_keys, :type => Array, :default => []
    field :user_info, :type => Hash, :default => {}
  end

  module ClassMethods
    def authenticate(fields)
      puts "FIELDS #{fields.inspect}"

      provider = fields["provider"]

      if fields["uid"] =~ %r{google\.com/accounts/o8/} && fields["user_info"]["email"]
        fields["uid"] = "http://google_id_#{fields["user_info"]["email"]}" # normalize for subdomains
      end

      uid = fields["uid"] || fields["extra"]["user_hash"]["id"]
      auth_key = "#{provider}_#{uid}"
      user = User.where({:auth_keys.in => [auth_key]}).first
      if user.nil?
        user = User.new
        user.auth_keys = [auth_key]

        puts ">>>>>>> #{provider} #{fields["user_info"].inspect}"
        user.user_info[provider] = fields["user_info"]

        if user.email.blank?
          user.email = user.user_info[provider]["email"]
        end

        user.send("handle_#{provider}", fields) if user.respond_to?("handle_#{provider}", true)

        if user.login.blank?
          if user.email.blank?
            user.login = user.user_info[provider]["nickname"] || user.user_info[provider]["login"] || user.user_info[provider]["name"] || "#{provider}_#{rand(100)}#{rand(100)}#{rand(100)}"
          else
            user.login = user.email.split("@").first.downcase.gsub(".","")
          end
        end

        # To handle: Facebook login issue
        if user.password.blank? && provider =~ /facebook|Facebook/
          user.password = Devise.friendly_token[0,20]
        end

        if !user.valid? && !user.errors[:login].empty?
          user.login = user.login + "_#{rand(100)}#{rand(100)}#{rand(100)}"
        end

        if !user.save
          Rails.logger.info "Invalid new user from #{provider}: #{user.errors.full_messages.inspect}"
          return false
        end
      end
      user.check_user_info(fields,provider)
      user
    end
  end # ClassMethods

  #InstanceMethods
  def connect(fields)
    provider = fields["provider"]
    self.check_user_info(fields, provider)
    if fields["uid"] =~ %r{google\.com/accounts/o8/} && fields["user_info"]["email"]
      fields["uid"] = "http://google_id_#{fields["user_info"]["email"]}" # normalize for subdomains
    end

    auth_key = "#{provider}_#{fields["uid"]}"
    user = User.where({:auth_keys.in => [auth_key]}).first
    self.push(:"user_info.#{provider}" => fields["user_info"])

    if user.present? && user.id != self.id
      if merge_user(user)
        user.destroy
        user = self
      end
    end
    user = self if user.nil?
    if user.respond_to?("handle_#{provider}", true)
      user.send("handle_#{provider}", fields)
      user.save!
      user.check_user_info(fields, provider)
    end

    self.push_uniq(:auth_keys => auth_key)
  end

  def merge_user(user)
    [Answer, Question].each do |class_name|
      class_name.relations.each do |relation|
        relation_name = relation[0]
        relation_kind = relation[1][:relation]
        if [Mongoid::Relations::Embedded::Many,
            Mongoid::Relations::Embedded::One].include? relation_kind
          objects = class_name.
            any_of([:"#{relation_name}.user_id" => user.id],
                   [:"#{relation_name}.created_by" => user.id],
                   [:"#{relation_name}.updated_by" => user.id])

          objects.each do |object|
            object.send(relation_name).each do |embedded_doc|
              %w(user_id created_by updated_by).each do |attr|
                if embedded_doc.respond_to?(attr) &&
                    embedded_doc.send(attr) == user.id
                  embedded_doc.public_send("#{attr}=", self.id)
                end
              end
              object.save if object.changed?
            end
          end
        end
      end
    end
    [Badge, UserStat, ReadList, Search, Activity, Invitation,
     ReputationStat, Page, Tag, Question, Answer].each do |m|
      m.override({:user_id => user.id}, {:user_id => self.id})
    end

    Activity.where(:"follower_ids" => user.id).each do |activity|
      activity.follower_ids.delete(user.id)
      activity.follower_ids = activity.follower_ids && [self.id]
      activity.save
    end

    Activity.where(:"trackable_info.user_id" => user.id).each do |activity|
      activity.trackable_info["user_id"] = self.id
      activity.trackable_info["user_param"] = self.login
      activity.save
    end

    Question.override({:updated_by_id => user.id},
                      {:updated_by_id => self.id})
    Question.override({:last_target_user_id => user.id},
                      {:last_target_user_id => self.id})
    Group.override({:owner_id => user.id},
                   {:owner_id => self.id})
    self.friend_list.follower_ids = self.friend_list.follower_ids.delete(user.id) &&
                                   user.friend_list.follower_ids.delete(self.id)
    self.friend_list.following_ids = self.friend_list.following_ids.delete(user.id) &&
                                   user.friend_list.following_ids.delete(self.id)
    user.memberships.each do |m|
      if self_membership = Membership.where(:user_id=>self.id,
                                            :group_id => m.group_id).first
        if m.role == 'owner'
          self_membership.role = 'owner'
        elsif m.role == 'moderator' && self_membership.role != 'owner'
          self_membership.role = 'moderator'
        end
        if m.is_editor
          self_membership.is_editor = true
        end
        self_membership.reputation += m.reputation
        self_membership.votes_up += m.votes_up
        self_membership.votes_down += m.votes_down
        self_membership.views_count += m.views_count
        self_membership.preferred_tags =
          self_membership.preferred_tags &&
          m.preferred_tags
        self_membership.save
        m.destroy
      end
    end
    Membership.override({:user_id => user.id}, {:user_id => self.id})
    begin
      if user.facebook_login?
        self.update({ :facebook_id => user.facebook_id, :facebook_token => user.facebook_token })
        self.external_friends_list.friends["facebook"] = user.external_friends_list.friends["facebook"]
        self.external_friends_list.save
        self.override(:"user_info.facebook" => user.user_info["facebook"]) if user_info["facebook"].blank?
      end
      if user.twitter_login?
        User.override({ :_id => self.id }, { :twitter_id => user.twitter_id, :twitter_token => user.twitter_token,
                      :twitter_secret => user.twitter_secret, :twitter_login => user.twitter_login})
        self.external_friends_list.friends["twitter"] = user.external_friends_list.friends["twitter"]
        self.external_friends_list.save
        self.override(:"user_info.twitter" => user.user_info["twitter"]) if user_info["twitter"].blank?
      end
      if user.identica_login?
        User.override({ :_id => self.id }, { :identica_id => user.identica_id,
                        :identica_secret => user.identica_secret,
                        :identica_token => user.identica_token})
        self.external_friends_list.friends["identica"] = user.external_friends_list.friends["identica"]
        self.external_friends_list.save
        self.override(:"user_info.identica" => user.user_info["identica"]) if user_info["identica"].blank?
      end
      if user.linked_in_login?
        User.override({ :_id => self.id }, { :linked_in_id => user.linked_in_id,
                        :linked_in_secret => user.linked_in_secret,
                        :linked_in_token => user.linked_in_token})
        self.external_friends_list.friends["linked_in"] = user.external_friends_list.friends["linked_in"]
        self.external_friends_list.save
        self.override(:"user_info.linked_in" => user.user_info["linked_in"]) if user_info["linked_in"].blank?
      end
    rescue Exception => e
      Rails.logger.info e.message
      return nil
    end
    user
  end

  def password_required?
    return false if self[:using_openid] || self[:facebook_id].present? || self[:twitter_id].present? || self[:github_id].present?

    (encrypted_password.blank? || !password.blank?)
  end

  def twitter_client
    if self.twitter_secret.present? && self.twitter_token.present? && (config = Multiauth.providers["Twitter"])
      TwitterOAuth::Client.new(
        :consumer_key => config["id"],
        :consumer_secret => config["token"],
        :token => self.twitter_token,
        :secret => self.twitter_secret
      )
    end
  end

  def facebook_client(property = 'friends', params = 'fields[]=name&fields[]=picture&fields[]=locale')
    response = open(URI.encode("https://graph.facebook.com/#{self.facebook_id}/#{property}?access_token=#{self.facebook_token}&#{params}")).read
    JSON.parse(response)
  end

  def identica_client
    config = Multiauth.providers["Identica"]
    @consumer = OAuth::Consumer.new(config["id"], config["token"], {:site=>'http://identi.ca'})
    @accesstoken = OAuth::AccessToken.new(@consumer, self.identica_token, self.identica_secret)
  end

  def linked_in_client
    config = Multiauth.providers["LinkedIn"]
    @consumer = OAuth::Consumer.new(config["id"], config["token"], {:site=>'http://api.linkedin.com'})
    @accesstoken = OAuth::AccessToken.new(@consumer, self.linked_in_token, self.linked_in_secret)
  end

  def get_identica_friends
    JSON.parse(identica_client.get('/api/statuses/friends.json').body)
  end

  def get_linked_in_friends
    friends = []
    JSON.parse(linked_in_client.
                get("/v1/people/~/connections:(id,first-name,last-name,picture-url,location)", 'x-li-format' => 'json').
      body)["values"].map do |friend| friends << { "id" => friend["id"],
        "name" => "#{friend["firstName"]} #{friend["lastName"]}",
        "profile_image_url" => friend["pictureUrl"], "country-code" => friend["location"]["country"]["code"]} end
    friends
  end

  def check_social_friends
    if self.facebook_login? && self.facebook_friends.blank?
      Jobs::Users.async.get_facebook_friends(self.id).commit!
    end
    if self.twitter_login? && self.twitter_friends.blank?
      Jobs::Users.async.get_twitter_friends(self.id).commit!
    end
    if self.identica_login? && self.identica_friends.blank?
      Jobs::Users.async.get_identica_friends(self.id).commit!
    end
    if self.linked_in_login? && self.linked_in_friends.blank?
      Jobs::Users.async.get_linked_in_friends(self.id).commit!
    end
  end

  def check_user_info(fields, provider)

    p "check_user_info I"
    user = self
    if provider == 'linked_in' && user.user_info["linked_in"].blank?
      user.user_info["linked_in"] = fields["user_info"]
      user.save(:validate => false)
    end
    if provider == 'identica' && user.user_info["identica"].blank?
      user.user_info["identica"] = fields["user_info"]
      user.save(:validate => false)
    end
    if provider == 'twitter' && ((user.user_info["twitter"] && user.user_info["twitter"]["old"]) || (user.user_info["twitter"].blank?))
      user.user_info["twitter"] = fields["user_info"]
      user.save(:validate => false)
    end
    if provider == 'facebook' && ((user.user_info["facebook"] && user.user_info["facebook"]["old"]) || (user.user_info["facebook"].blank?))
      user.user_info["facebook"] = fields["user_info"]
      user.save(:validate => false)
    end
    p "check_user_info E"
  end

  private
  # {"provider"=>"facebook", "uid"=>"4332432432432", "credentials"=>{"token"=>"432432432432432"},
  # "user_info"=>{"nickname"=>"profile.php?id=4332432432432", "first_name"=>"My", "last_name"=>"Name", "name"=>"My Name", "urls"=>{"Facebook"=>"http://www.facebook.com/profile.php?id=4332432432432", "Website"=>nil}},
  # "extra"=>{"user_hash"=>{"id"=>"4332432432432", "name"=>"My Name", "first_name"=>"My", "last_name"=>"Name", "link"=>"http://www.facebook.com/profile.php?id=4332432432432", "birthday"=>"06/15/1980", "gender"=>"male", "email"=>"my email", "timezone"=>-5, "locale"=>"en_US", "updated_time"=>"2010-04-01T07:27:28+0000"}}}
  def handle_facebook(fields)
    uinfo = fields["extra"]["user_hash"].clone
    self.facebook_id = fields["uid"].to_s
    self.facebook_token = fields["credentials"]["token"].to_s
    self.facebook_profile = fields["user_info"]["urls"]["Facebook"].to_s

    if self.email.blank?
      self.email = uinfo["email"]
    end
  end

  # {"provider"=>"twitter", "uid"=>"user id", "credentials"=>{"token"=>"token", "secret"=>"secret"},
  # "extra"=>{"access_token"=>token_object, "user_hash"=>{"description"=>"desc", "screen_name"=>"nick", "geo_enabled"=>false, "profile_sidebar_border_color"=>"87bc44", "status"=>{}}},
  # "user_info"=>{"nickname"=>"nick", "name"=>"My Name", "location"=>"Here", "image"=>"http://a0.twimg.com/profile_images/path.png", "description"=>"desc", "urls"=>{"Website"=>nil}}}
  def handle_twitter(fields)
    p "handle_twitter I"
    self.twitter_token = fields["credentials"]["token"].to_s
    self.twitter_secret = fields["credentials"]["secret"].to_s
    self.twitter_login = fields["user_info"]["nickname"].to_s
    self.twitter_id = fields["uid"].to_s

    self.login.blank? && self.login = fields["user_info"]["nickname"]
    p "handle_twitter E"
  end

  def handle_identica(fields)
    self.identica_token = fields["credentials"]["token"].to_s
    self.identica_secret = fields["credentials"]["secret"].to_s
    self.identica_login = fields["user_info"]["nickname"].to_s
    self.identica_id = fields["uid"].to_s

    self.login.blank? && self.login = fields["user_info"]["nickname"].to_s
  end

  def handle_linked_in(fields)
    self.linked_in_token = fields["credentials"]["token"].to_s
    self.linked_in_secret = fields["credentials"]["secret"].to_s
    self.linked_in_id = fields["uid"].to_s
    self.bio.blank? && self.bio = fields["user_info"]["description"].to_s

    self.login.blank? && self.login = fields["user_info"]["first_name"].to_s+fields["user_info"]["last_name"].to_s
  end
  #end InstanceMethods
end
