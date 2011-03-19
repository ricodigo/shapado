module Jobs
  class Users
    extend Jobs::Base

    def self.post_to_twitter(user_id, text)
      user = User.find(user_id)

      client = user.twitter_client

      client.update(text)
    end

    def self.on_update_user(user_id, group_id)
      user = User.find(user_id)
      group = Group.find(group_id)

      if !user.birthday.blank? && !user.website.blank? && !user.bio.blank? && !user.name.blank?
        create_badge(user, group, :token => "autobiographer", :unique => true)
      end
    end

    def self.get_facebook_friends(user_id)
      user = User.find(user_id)
      friends = user.facebook_client
      user.facebook_friends_list.friends = friends["data"]
      user.facebook_friends_list.save
      user.save
    end

    def self.get_twitter_friends(user_id)
      user = User.find(user_id)
      friends = user.twitter_client.friends_ids
      user.twitter_friends_list.friends = friends
      user.twitter_friends_list.save
      user.save
    end

    def self.get_identica_friends(user_id)
      user = User.find(user_id)
      friends = user.get_identica_friends
      user.identica_friends_list.friends = friends
      user.identica_friends_list.save
      user.save
    end

    def self.get_linked_in_friends(user_id)
      user = User.find(user_id)
      friends = user.get_linked_in_friends
      user.linked_in_friends_list.friends = friends
      user.linked_in_friends_list.save
      user.save
    end
  end
end
