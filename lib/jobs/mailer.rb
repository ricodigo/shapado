module Jobs
  class Mailer
    extend Jobs::Base

    def self.on_ask_question(question_id)
      question = Question.find!(question_id)
      group = question.group
      users = User.find_experts(question.tags, [question.language],
                                                :except => [question.user.id],
                                                :group_id => group.id)
      followers = question.user.followers(:group_id => group.id, :languages => [question.language])

      (users - followers).each do |u|
        if !u.email.blank?
          Notifier.give_advice(u, group, question, false).deliver
        end
      end

      followers.each do |u|
        if !u.email.blank?
          Notifier.give_advice(u, group, question, true).deliver
        end
      end
    end

    def self.on_new_comment(commentable_id, commentable_class, comment_id)
      commentable = commentable_class.constantize.find(commentable_id)
      comment = commentable.comments.detect {|comment| comment.id == comment_id}
      if comment && (recipient = comment.find_recipient)
        email = recipient.email
        if !email.blank? && comment.user.id != recipient.id && recipient.notification_opts.new_answer
          Notifier.new_comment(commentable.group, comment, recipient, commentable).deliver
        end
      end
    end

    def self.on_favorite_answer(answer_id, current_user_id)
      current_user = User.find(current_user_id)
      answer = Answer.find(answer_id)
      if (answer.user_id != current_user.id) && current_user.notification_opts.activities
        Notifier.favorited(current_user, answer.group, answer).deliver
      end
    end

    def self.on_follow(current_user_id, user_id, current_group_id)
      current_user = User.find(current_user_id)
      current_group = Group.find(current_group_id)
      user = User.find(user_id)
      if user.notification_opts.activities
        Notifier.deliver_follow(current_user, user, current_group)
      end
    end

    def self.on_new_invitation(invitation_id)
      Notifier.new_invitation(invitation_id).deliver
    end
  end
end
