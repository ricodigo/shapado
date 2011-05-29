module Jobs
  class Activities
    extend Jobs::Base

    def self.on_activity(group_id, user_id)
      user = User.where(:_id => user_id).only(:_id).first
      group = Group.where(:_id => group_id).only(:_id).first

      days = user.config_for(group).activity_days
      if days > 100
        create_badge(user, group, :token => "fanatic", :unique => true)
      elsif days > 20
        create_badge(user, group, :token => "addict", :unique => true)
      elsif days > 8
        create_badge(user, group, :token => "shapado", :unique => true)
      end
    end

    def self.on_update_answer(answer_id)
      answer = Answer.find(answer_id)
      user = answer.updated_by

      create_badge(user, answer.group, :token => "editor", :unique => true)
    end

    def self.on_create_answer(answer_id)
      answer = Answer.find(answer_id)
      answer.set_address
    end

    def self.on_destroy_answer(user_id, attributes)
      deleter = User.find!(user_id)
      group = Group.find(attributes["group_id"])

      if deleter.id == attributes["user_id"]
        if attributes["votes_average"] >= 3
          create_badge(deleter, group, :token => "disciplined", :unique => true)
        end

        if attributes["votes_average"] <= -3
          create_badge(deleter, group, :token => "peer_pressure", :unique => true)
        end
      end
    end

    def self.on_comment(commentable_id, commentable_class, comment_id)
      commentable = commentable_class.constantize.find(commentable_id)
      comment = commentable.comments.find(comment_id)
      group = commentable.group
      user = comment.user
#       comment.set_address FIXME
      if user.config_for(group).comments_count >= 10
        create_badge(user, group, :token => "commentator", :source => comment, :unique => true)
      end
      if user.notification_opts.comments_to_twitter
        shortlink = shorten_url(link, answer)
        author = user
        title = comment.question.title
        message = I18n.t('jobs.comments.on_comment.send_twitter',
                         :question => title, :locale => author.language)
        status = make_status(message, shortlink, 138)
        author.twitter_client.update(status)
      end
      if group.notification_opts.comments_to_twitter
        shortlink ||= shorten_url(link, answer)
        author ||= user
        title ||= comment.question.title
        message = I18n.t('jobs.comments.on_comment.group_send_twitter',
                         :question => title, :user => author.login,
                         :locale => author.language)
        status = make_status(message, shortlink, 138)
        group.twitter_client.update(status)
      end
    end

    def self.on_follow(follower_id, followed_id, group_id)
      follower = User.find(follower_id)
      followed = User.find(followed_id)
      group = Group.find(group_id)

      if follower.following_count > 1
        create_badge(follower, group, :token => "friendly",:source => followed, :unique => true)
      end

      if followed.followers_count >= 100
        create_badge(followed, group, :token => "celebrity",:unique => true)
      elsif followed.followers_count >= 50
        create_badge(followed, group, :token => "popular_person",:unique => true)
      elsif followed.followers_count >= 10
        create_badge(followed, group, :token => "interesting_person",:unique => true)
      end
    end

    def self.on_unfollow(follower_id, followed_id, group_id)
    end

    def self.on_flag(user_id, group_id, reason)
      group = Group.find(group_id)
      create_badge(User.find(user_id), group, :token => "citizen_patrol", :unique => true)
      group.mods_owners.each do |user|
        if !user.email.blank? && user.notification_opts.activities
          Notifier.created_flag(user, group, reason).deliver
        end
      end
    end

    def self.on_rollback(question_id)
      question = Question.find(question_id)
      create_badge(question.updated_by, question.group, :token => "cleanup", :source => question, :unique => true)
    end

    def self.on_admin_connect(ip, user_id)
      Notifier.admin_login(ip, user_id).deliver
    end
  end
end
