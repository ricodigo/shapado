module Shapado
  module Controllers
    module Routes
      def self.included(base)
        base.class_eval do
          helper_method :logo_path, :css_group_path,
                        :favicon_group_path, :tag_icon_path,
                        :avatar_user_path,
                        :logo_group_path,
                        :question_attachment_path
        end
      end

      def css_group_path(group)
        "/_files/groups/css/#{group.id}"
      end

      def favicon_group_path(group)
        "/_files/groups/favicon/#{group.id}"
      end

      def tag_icon_path(group,tag_name)
        if tag_name.is_a?(Tag)
          tag_name = tag_name.name
        end
        "/_files/tags/icon/#{group.id}/#{tag_name}"
      end

      def avatar_user_path(user, size = nil)
        prefix = "avatar"
        if !size.nil? && ["big", "medium", "small"].include?(size)
          prefix = size
        end
        "/_files/users/#{prefix}/#{user.id}"
      end

      def logo_path(group, size = nil)
        prefix = "logo"
        if !size.nil? && ["big", "medium", "small"].include?(size)
          prefix = size
        end
        "/_files/groups/#{prefix}/#{group.id}"
      end

      def question_attachment_path(group,question, file, attach_id)
        "/_files/questions/attachment/#{group.slug}/#{question.id}/#{attach_id}/#{file.name}"
      end
    end
  end
end