
desc "Fix all"
task :fixall => [:init, "fixdb:questions", "fixdb:contributions", "fixdb:dates", "fixdb:openid", "fixdb:relocate", "fixdb:votes", "fixdb:counters", "fixdb:sync_counts", "fixdb:last_target_type", "fixdb:comments", "fixdb:widgets", "fixdb:tags", "fixdb:update_answers_favorite", "fixdb:groups", "fixdb:remove_retag_other_tag", "setup:create_reputation_constrains_modes", "fixdb:update_group_notification_config", "fixdb:set_follow_ids", "fixdb:set_friends_list", "fixdb:fix_twitter_users", "fixdb:fix_facebook_users"] do
end


task :init => [:environment] do
  class Question
    def set_created_at; end
    def set_updated_at; end
  end

  class Answer
    def set_created_at; end
    def set_updated_at; end
  end

  class Group
    def set_created_at; end
    def set_updated_at; end
  end
end

namespace :fixdb do
  task :questions => [:init] do
    Question.all.each do |question|
      question.override(:_random => rand())
      question.override(:_random_times => 0.0)

      watchers = question.raw_attributes["watchers"]
      question.unset(:watchers => true)
      if watchers.kind_of?(Array)
        question.override(:follower_ids => watchers)
      end
    end
  end

  task :contributions => [:init] do
    Question.only(:user_id, :contributor_ids).all.each do |question|
      question.add_contributor(question.user) if question.user
      question.answers.only(:user_id).all.each do |answer|
        question.add_contributor(answer.user) if answer.user
      end
    end
  end

  task :dates => [:init] do
    %w[badges questions comments votes users announcements groups memberships pages reputation_events user_stats versions views_counts].each do |cname|
      coll = Mongoid.master.collection(cname)
      coll.find.each do |q|
        %w[activity_at last_target_date created_at updated_at birthday last_logged_at starts_at ends_at last_activity_at time date].each do |key|
          if q[key].is_a?(String)
            q[key] = Time.parse(q[key])
          end
        end
        coll.save(q)
      end
    end
  end

  task :openid => [:init] do
    User.all.each do |user|
      next if user.identity_url.blank?

      puts "Updating: #{user.login}"
      user.push_uniq(:auth_keys => "open_id_#{user[:identity_url]}")
      user.unset(:identity_url => 1)
    end
  end

  task :update_answers_favorite => [:init] do
    Mongoid.database.collection("favorites").remove
    answers = Mongoid.database.collection("answers")
    answers.update({ }, {"$set" => {"favorite_counts" => 0}})
  end

  task :sync_counts => [:init] do
    votes = Mongoid.database.collection("votes")
    comments = Mongoid.database.collection("comments")
    puts "updating comment's counts"
    comments.find.each do |c|
      print "."
      votes_average=0
      votes.find(:voteable_id =>  c["_id"]).each do |v|
        votes_average+=v["value"]
      end
      comments.update({:_id => c["id"]},
                      {"$set" => {"votes_count" => votes.find(:voteable_id =>  c["_id"]).count,
                                  "votes_average" => votes_average}})

      if c["flags"]
        comments.update({:_id => c["id"]}, {"$set" => {"flags_count" => c["flags"].size}})
      end
    end

    puts "updating questions's counts"
    Question.all.each do |q|
      print "."
      votes_average=0
      votes.find(:voteable_id =>  q.id).each do |v|
        votes_average+=v["value"]
      end
      q.override("flags_count" => q.flags.size, "votes_count" => q.votes.size, "votes_average" => votes_average)
    end
  end

  task :counters => :init do
    Question.all.each do |q|
      q.override(:close_requests_count => q.close_requests.size)
      q.override(:open_requests_count => q.open_requests.size)
    end
  end

  task :last_target_type => [:init] do
    puts "updating questions#last_target_type"
    Question.where({:last_target_type.ne => nil}).all.each do |q|
      print "."
      if(q.last_target_type != "Comment")
        last_target = q.last_target_type.constantize.find(q.last_target_id)
      else
        data = Mongoid.database.collection("comments").find_one(:_id => q.last_target_id)
        last_target = Comment.new(data)
      end

      if(last_target)
        if(last_target.respond_to?(:updated_at) && last_target.updated_at && last_target.updated_at.is_a?(String))
          last_target.updated_at = Time.parse(last_target.updated_at)
        end
        Question.update_last_target(q.id, last_target)
      end
    end
  end

  task :votes => [:init] do
    puts "updating votes"
    comments = Mongoid.database.collection("comments")
    comments.update({:votes => nil}, {"$set" => {"votes" =>  {}}}, :multi => true)
    questions = Mongoid.database.collection("questions")
    questions.update({:votes => nil}, {"$set" => {"votes" => {}}}, :multi => true)
    Group.all.each do |group|
      count = 0
      Mongoid.database.collection("votes").find({:group_id => group["_id"]}).each do |vote|
        vote.delete("group_id")
        id = vote.delete("voteable_id")
        klass = vote.delete("voteable_type")
        collection = comments
        if klass == "Question"
          collection = questions;
        end
        count += 1
        collection.update({:_id => id}, "$set" => {"votes.#{vote["user_id"]}" => vote["value"]})
      end
      if count > 0
        puts "Updated #{count} #{group["name"]} votes"
      end
    end
    Mongoid.database.collection("votes").drop
  end

  task :comments => [:init] do
    puts "updating comments"
    comments = Mongoid.database.collection("comments")
    questions = Mongoid.database.collection("questions")

    Mongoid.database.collection("comments").find(:_type => "Comment").each do |comment|
        id = comment.delete("commentable_id")
        klass = comment.delete("commentable_type")
        collection = comments

      %w[created_at updated_at].each do |key|
        if comment[key].is_a?(String)
          comment[key] = Time.parse(comment[key])
        end
      end

      if klass == "Question"
        collection = questions;
      end

        collection.update({:_id => id}, "$addToSet" => {:comments => comment})
        comments.remove({:_id => comment["_id"]})
    end
    begin
      Mongoid.database.collection("answers").drop
    ensure
      begin
        comments.rename("answers")
      rescue
        puts "comments collection doesn't exists"
      ensure
        Answer.override({}, {:_type => "Answer"})
      end
    end

    answers_coll = Mongoid.database.collection("answers")
    answers_coll.find().each do |answer|
      %w[created_at updated_at].each do |key|
        if answer[key].is_a?(String)
          answer[key] = Time.parse(answer[key])
        end
      end
      answers_coll.save(answer)
    end

    puts "updated comments"
  end

  task :groups => [:init] do
    Group.where({:language.in => [nil, '', 'none']}).all.each do |group|
      lang = group.description.to_s.language
      puts "Updating #{group.name} subdomain='#{group.subdomain}' detected as: #{lang}"

      group.language = (lang == :spanish) ? 'es' : 'en'
      group.languages = DEFAULT_USER_LANGUAGES
      if group.valid?
        group.save
      else
        puts "Invalid group: #{group.errors.full_messages}"
      end
    end
  end

  task :relocate => [:init] do
    doc = JSON.parse(File.read('data/countries.json'))
    i=0
    Question.override({:address => nil}, :address => {})
    Answer.override({:address => nil}, :address => {})
    User.override({:address => nil}, :address => {})
    doc.keys.each do |key|
      User.where({:country_name => key}).all.each do |u|
        p "#{u.login}: before: #{u.country_name}, after: #{doc[key]["address"]["country"]}"
        lat = doc[key]["lat"]
        lon = doc[key]["lon"]
        User.override({:_id => u.id},
                    {:position => {lat: lat, long: lon},
                      :address => doc[key]["address"] || {}})
#         FIXME
#         Comment.override({:user_id => u.id},
#                     {:position => GeoPosition.new(lat, lon),
#                       :address => doc[key]["address"]})
        Question.override({:user_id => u.id},
                    {:position => {lat: lat, long: lon},
                      :address => doc[key]["address"] || {}})
        Answer.override({:user_id => u.id},
                    {:position => {lat: lat, long: lon},
                      :address => doc[key]["address"] || {}})
      end
    end
  end

  task :widgets => [:init] do
    c=Group.count
    Group.unset({}, {:widgets => true, :question_widgets => true, :mainlist_widgets => true,
                :external_widgets => true})
    i=0
    Group.all.each do |g|
      [SharingButtonsWidget, ModInfoWidget, QuestionBadgesWidget,
       QuestionStatsWidget, QuestionTagsWidget, RelatedQuestionsWidget,
       TagListWidget, CurrentTagsWidget].each do |w|
        widget = w.new
        g.question_widgets << widget
      end

      [BadgesWidget, PagesWidget, TopGroupsWidget, TopUsersWidget, TagCloudWidget].each do |w|
        g.mainlist_widgets << w.new
      end
      g.external_widgets << AskQuestionWidget.new
      g.save
      p "(#{i+=1}/#{c}) Updated widgets for group #{g.name}"
    end
  end

  task :update_group_notification_config => [:init] do
    puts "updating groups notification config"
    Group.all.each do |g|
      g.notification_opts = GroupNotificationConfig.new
      g.save
    end
    puts "done"
  end

  task :tags => [:init] do
    Group.all.each do |g|
      Question.tag_cloud({:group_id => g.id} , 1000).each do |tag|
        tag = Tag.new(:name => tag["name"], :count => tag["count"])
        tag.group = g
        tag.user = g.owner
        tag.used_at = tag.created_at = tag.updated_at = g.questions.where(:tags.in => [tag["name"]]).first.created_at
        tag.save
      end
    end
  end

  task :remove_retag_other_tag => [:init] do
    Group.unset({}, "reputation_constrains.retag_others_tags" => 1 )
  end

  task :cleanup => [:init] do
    p "removing #{Question.where(:group_id => nil).destroy_all} orphan questions"
    p "removing #{Answer.where(:group_id => nil).destroy_all} orphan answers"
  end

  task :set_follow_ids => [:init] do
    p "setting nil following_ids to []"
    FriendList.collection.update({:following_ids => nil}, {:following_ids => []})
    p "setting nil follower_ids to []"
    FriendList.collection.update({:follower_ids => nil}, {:follower_ids => []})
    p "done"
  end

  task :set_friends_lists => [:init] do
    total = User.count
    i = 1
    p "updating #{total} users facebook friends list"
    User.all.each do |u|
      u.facebook_friends_list = FacebookFriendsList.create
      u.twitter_friends_list = TwitterFriendsList.create
      u.identica_friends_list = IdenticaFriendsList.create
      u.linked_in_friends_list = LinkedInFriendsList.create

      p "#{i}/#{total} #{u.login}"
      i += 1
    end
    p "done"
  end

  task :fix_twitter_users => [:init] do
    users = User.where({:twitter_token => {:$ne => nil}})
    users.each do |u|
      twitter_id = u.twitter_token.split('-').first
      p "fixing #{u.login} with twitter id #{twitter_id}"
      u["auth_keys"] = [] if u["auth_keys"].nil?
      u["auth_keys"] << "twitter_#{twitter_id}"
      u["auth_keys"].uniq!
      u["twitter_id"] = twitter_id
      u["user_info"] = { } if u["user_info"].nil?
      u["user_info"]["twitter"] = { "old" => 1}
      u.save(:validate => false)
    end
  end

  task :fix_facebook_users => [:init] do
    users = User.where({:facebook_id => {:$ne => nil}})
    users.each do |u|
      facebook_id = u.facebook_id
      p "fixing #{u.login} with facebook id #{facebook_id}"
      u["auth_keys"] = [] if u["auth_keys"].nil?
      u["auth_keys"] << "facebook_#{facebook_id}"
      u["auth_keys"].uniq!
      u["user_info"] = { } if u["user_info"].nil?
      u["user_info"]["facebook"] = { "old" => 1}
      u.save(:validate => false)
    end
  end
end
