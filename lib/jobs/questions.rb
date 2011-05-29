module Jobs
  class Questions
    extend Jobs::Base

    def self.on_question_solved(question_id, answer_id)
      question = Question.find(question_id)
      answer = Answer.find(answer_id)
      group = question.group

      if question.answer == answer && group.answers.where(:user_id => answer.user.id).count == 1
        create_badge(answer.user, group, :token => "troubleshooter", :source => answer, :unique => true)
      end

      if question.answer == answer && answer.votes_average >= 10
        create_badge(answer.user, group, {:token => "enlightened", :source => answer}, {:unique => true, :source_id => answer.id})
      end

      if question.answer == answer && answer.votes_average >= 40
        create_badge(answer.user, group, {:token => "guru", :source => answer}, {:unique => true, :source_id => answer.id})
      end

      if question.answer == answer && answer.votes_average > 2
        answer.user.stats.add_expert_tags(*question.tags)
        create_badge(answer.user, group, :token => "tutor", :source => answer, :unique => true)
      end

      if question.user_id == answer.user_id
        create_badge(answer.user, group, :token => "scholar", :source => answer, :unique => true)
      end
    end

    def self.on_question_unsolved(question_id, answer_id)
      question = Question.find(question_id)
      answer = Answer.find(answer_id)
      group = question.group

      if answer && question.answer.nil?
        user_badges = answer.user.badges
        badge = user_badges.where(:token => "troubleshooter", :group_id => group.id, :source_id => answer.id).first
        badge.destroy if badge

        badge = user_badges.where(:token => "guru", :group_id => group.id, :source_id => answer.id).first
        badge.destroy if badge
      end

      if answer && question.answer.nil?
        user_badges = answer.user.badges
        tutor = user_badges.where(:token => "tutor", :group_id => group.id, :source_id => answer.id).first
        tutor.destroy if tutor
      end
    end

    def self.on_view_question(question_id)
      question = Question.find!(question_id)
      user = question.user
      group = question.group

      views = question.views_count
      opts = {:source_id => question.id, :source_type => "Question", :unique => true}
      if views >= 1000
        create_badge(user, group, {:token => "popular_question", :source => question}, opts)
      elsif views >= 2500
        create_badge(user, group, {:token => "notable_question", :source => question}, opts)
      elsif views >= 10000
        create_badge(user, group, {:token => "famous_question", :source => question}, opts)
      end
    end

    def self.on_ask_question(question_id,link)
      question = Question.find!(question_id)
      user = question.user
      group = question.group
      question.set_address
      if group.questions.where(:user_id => user.id).count == 1
        create_badge(user, group, :token => "inquirer", :source => question, :unique => true)
      end
      if user.notification_opts.questions_to_twitter
        shortlink = shorten_url(link, question)
        status = make_status(question.title, shortlink, 138)
        user.twitter_client.update(status)
      end
      if group.notification_opts.questions_to_twitter
        shortlink ||= shorten_url(link, question)
        status ||= make_status(question.title, shortlink, 138)
        group.twitter_client.update(status)
      end
    end

    def self.on_destroy_question(user_id, attributes)
      deleter = User.find(user_id)
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

    def self.on_question_followed(question_id)
      question = Question.find(question_id)
      user = question.user
      group = question.group
      if question.followers_count >= 25
        create_badge(user, group, {:token => "favorite_question", :source => question}, {:unique => true, :source_id => question.id})
      end

      if question.followers_count >= 100
        create_badge(user, group, {:token => "stellar_question", :source => question}, {:unique => true, :source_id => question.id})
      end
    end

    def self.on_retag_question(question_id, user_id)
      question = Question.find(question_id)
      user = User.find(user_id)

      create_badge(user, question.group, {:token => "organizer", :source => question, :unique => true})
    end

    def self.close_reward(question_id)
      question = Question.find(question_id)
      if question.reward && question.reward.ends_at < Time.now
        question.reward.reward(question.group)
      end
    end

    def self.on_start_reward(question_id)
      question = Question.find(question_id)
      if question.reward && question.reward.ends_at > Time.now
        user = question.reward.created_by
        group = question.group

        if question.user_id != question.reward.created_by_id
          create_badge(user, group, {:token => "investor", :source => question}, {:unique => true, :source_id => question.id})
        elsif question.user_id == question.reward.created_by_id
          create_badge(user, group, {:token => "promoter", :source => question}, {:unique => true, :source_id => question.id})
        end
      end
    end

    def self.on_close_reward(question_id, answer_id, user_id)
      question = Question.find(question_id)
      user = User.find(user_id)
      receiver = Answer.only(:user_id).where(:_id => answer_id).first.user_id

      group = question.group

      if receiver != user_id
        if question.user_id != user_id
          create_badge(user, group, {:token => "altruist", :source => question}, {:unique => true, :source_id => question.id})
        elsif question.user_id == user_id
          create_badge(user, group, {:token => "benefactor", :source => question}, {:unique => true, :source_id => question.id})
        end
      end

    end
  end
end
