module Jobs
  class Images
    extend Jobs::Base

    def self.generate_user_thumbnails(user_id)
      user = User.find(user_id)
      if user.has_avatar?
        generate_thumbnails(user, user.avatar)
      end
    end

    def self.generate_group_thumbnails(group_id)
      group = Group.find(group_id)
      if group.has_logo?
        generate_thumbnails(group, group.logo)
      end
    end

    private
    def self.generate_thumbnails(object, original_image)
      {"big" => "140x140", "medium" => "60x60", "small" => "25x25"}.each do |name, size|
        image = ::MiniMagick::Image.read(original_image.get)
        image.resize "#{size}!"

        if object.thumbnails[name]
          object.thumbnails.get(name).delete
        end

        object.thumbnails.put(name, image.to_blob)
        image.destroy!
        original_image.reset
        object.save
      end
    end
  end
end
