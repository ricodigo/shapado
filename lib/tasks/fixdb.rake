
desc "Fix all"
task :fixall => [:init, "fixdb:questions", "fixdb:contributions", "fixdb:dates", "fixdb:openid", "fixdb:relocate", "fixdb:votes", "fixdb:counters", "fixdb:sync_counts", "fixdb:last_target_type", "fixdb:comments", "fixdb:widgets", "fixdb:tags", "fixdb:update_answers_favorite", "fixdb:groups", "fixdb:remove_retag_other_tag", "setup:create_reputation_constrains_modes", "fixdb:update_group_notification_config", "fixdb:set_follow_ids", "fixdb:set_friends_lists", "fixdb:fix_twitter_users", "fixdb:fix_facebook_users", "fixdb:create_thumbnails", "fixdb:set_invitations_perms", "fixdb:set_signup_type", "fixdb:set_comment_count", "fixdb:versions"] do
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
        lat = Float(doc[key]["lat"])
        lon = Float(doc[key]["lon"])
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
    Group.override({}, {:widgets => [], :question_widgets => [], :mainlist_widgets => [],
                        :external_widgets => []})
    i=0
    Group.all.each do |g|
      g.reset_widgets!
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
    FriendList.override({:following_ids => nil}, {:following_ids => []})
    p "setting nil follower_ids to []"
    FriendList.override({:follower_ids => nil}, {:follower_ids => []})
    p "done"
  end

  task :set_friends_lists => [:init] do
    total = User.count
    i = 1
    p "updating #{total} users facebook friends list"
    User.all.each do |u|
      u.send(:initialize_fields)
      u.send(:create_friends_lists)

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

  task :create_thumbnails => [:init]  do
    Group.all.each do |g|
      begin
        Jobs::Images.generate_group_thumbnails(g.id)
      rescue Mongo::GridFileNotFound => e
        puts "error getting #{g.name}'s logo"
      end
    end
  end


  task :set_invitations_perms => [:init] do
    p "setting invitations permissions on groups"
    p "only owners can invite people on private group by default"
    Group.override({:private => false}, {:invitations_perms => "owner"})
    p "anyone can invite people on private group by default"
    Group.override({:private => false}, {:invitations_perms => "user"})
    p "done"
  end

  task :set_signup_type => [:init] do
    p "setting signup type for groups"
    Group.override({:openid_only => true}, {:signup_type => "noemail"})
    Group.override({:openid_only => false}, {:signup_type => "all"})
    p "done"
  end

  task :set_comment_count => [:init] do
    User.where.only([:_id,:membership_list, :login]).each do |u|
      u.membership_list.each do |group_id, vals|
        count = 0
        group = Group.where(:_id => group_id).only([:_id, :name]).first
        next if group.nil?

        group.questions.only([:_id, :"comments.user_id"]).each do |q|
          q.comments.each do |c|
            if c.user_id == u.id
              count =  count + 1
            end
          end
          q.comments = []
        end

        group.answers.only([:_id, :"comments.user_id"]).each do |a|
          a.comments.each do |c|
            puts c.body.inspect
            if c.user_id == u.id
              count = count + 1
            end
          end
          a.comments = []
        end

        u.override({"membership_list.#{group.id}.comments_count" => count})
        if count > 0
          p "#{u.login}: #{count} in #{group.name}"
        end
      end
    end
  end

  task :versions => [:init] do
    Question.only(:versions, :versions_count).each do |question|
      next if question.versions.count > 0
      question.override({:versions_count => 0})
      (question[:versions]||[]).each do |version|
        version["created_at"] = version.delete("date")
        version["target"] = question

        question.version_klass.create!(version)
      end

      question.unset({:versions => true})
    end

    Answer.only(:versions, :versions_count).each do |post|
      next if post.versions_count.to_i > 0
      post.override({:versions_count => 0})
      (post[:versions]||[]).each do |version|
        version["created_at"] = version.delete("date")
        version["target"] = post

        post.version_klass.create!(version)
      end

      post.unset({:versions => true})
    end
  end

end
