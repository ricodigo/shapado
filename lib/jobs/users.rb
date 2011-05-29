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
      external_friends_list = user.external_friends_list
      external_friends_list.friends["facebook"] = friends["data"]
      external_friends_list.save
    end

    def self.get_twitter_friends(user_id)
      user = User.find(user_id)
      friends = user.twitter_client.all_friends.map do |friend|
        { "id" => friend["id_str"], "lang" => friend["id_str"],
        "profile_image_url" => friend["profile_image_url"],
        "name" => friend["name"] || friend["screen_name"]}
      end
      user.external_friends_list.friends["twitter"] = friends
      user.external_friends_list.save
      user.save
    end

    def self.get_identica_friends(user_id)
      user = User.find(user_id)
      friends = user.get_identica_friends
      unless friends[0]["error"]
        user.external_friends_list.friends["identica"] = friends
        user.external_friends_list.save
        user.save
      end
    end

    def self.get_linked_in_friends(user_id)
      user = User.find(user_id)
      friends = user.get_linked_in_friends
      user.external_friends_list.friends["linked_in"] = friends
      user.external_friends_list.save
      user.save
    end
  end
end
