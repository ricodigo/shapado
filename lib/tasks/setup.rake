desc "Setup application"
task :bootstrap => [:environment, "db:drop",
                    "setup:create_admin",
                    "setup:default_group",
                    "setup:create_reputation_constrains_modes",
                    "setup:create_widgets",
                    "setup:create_pages"] do
end

desc "Upgrade"
task :upgrade => [:environment] do
end

namespace :setup do

  desc "Reset admin password"
  task :reset_password => :environment do
    admin = User.where(:login => "admin").first
    admin.encrypted_password = nil
    admin.password = "admins"
    admin.password_confirmation = "admins"
    admin.save
  end

  desc "Create the default group"
  task :default_group => [:environment] do
    default_tags = %w[technology business science politics religion
                               sports entertainment gaming lifestyle offbeat]

    subdomain = AppConfig.application_name.gsub(/[^A-Za-z0-9\s\-]/, "")[0,20].strip.gsub(/\s+/, "-").downcase
    default_group = Group.new(:name => AppConfig.application_name,
                              :domain => AppConfig.domain,
                              :subdomain => subdomain,
                              :language => "en",
                              :domain => AppConfig.domain,
                              :description => "question-and-answer website",
                              :legend => "question and answer website",
                              :default_tags => default_tags,
                              :state => "active")

    if admin = User.where(:login => "admin").first
      default_group.owner = admin
      default_group.add_member(admin, "owner")
    end
    default_group.save!
    default_group.logo = File.open(Rails.root+"public/images/logo.png")
    default_group.save
  end

  desc "Create default widgets"
  task :create_widgets => :environment do
    default_group = Group.where(:domain => AppConfig.domain).first

    if AppConfig.enable_groups
      default_group.mainlist_widgets << GroupsWidget.new
    end
    default_group.mainlist_widgets << UsersWidget.new
    default_group.mainlist_widgets << BadgesWidget.new
    default_group.save!
  end

  desc "Create admin user"
  task :create_admin => [:environment] do
    admin = User.new(:login => "admin", :password => "admins",
                                        :password_confirmation => "admins",
                                        :email => "shapado@example.com",
                                        :role => "admin")
    admin.preferred_languages = AVAILABLE_LANGUAGES

    admin.save!
  end

  desc "Create user"
  task :create_user => [:environment] do
    user = User.new(:login => "user", :password => "user123",
                                      :password_confirmation => "user123",
                                      :email => "user@example.com",
                                      :role => "user")
    user.save!
  end

  desc "Create pages"
  task :create_pages => [:environment] do
    Dir.glob(Rails.root+"db/fixtures/pages/*.markdown") do |page_path|
      basename = File.basename(page_path, ".markdown")
      title = basename.gsub(/\.(\w\w)/, "").titleize
      language = $1

      body = File.read(page_path)

      puts "Loading: #{title.inspect} [lang=#{language}]"
      #Group.all.each do |group|
      #  if Page.where(:title => title, :language => language, :group_id => group.id).count == 0
      #    Page.create(:title => title, :language => language, :body => body, :user_id => group.owner, :group_id => group.id)
      #  end
      #end
    end
  end

  desc "Create reputation constrains modes"
  task :create_reputation_constrains_modes => [:environment] do
    ConstrainsConfig.destroy_all
    ConstrainsConfig.create(:name => "default", :content => REPUTATION_CONSTRAINS)
    bootstrap_content = {
      vote_up: 0,
      flag: 0,
      post_images: 0,
      comment: 0,
      delete_own_comments: 50,
      vote_down: 10,
      create_new_tags: 0,
      post_whithout_limits: 0,
      edit_wiki_post: 100,
      remove_advertising: 200,
      vote_to_open_own_question: 250,
      vote_to_close_own_question: 250,
      retag_others_questions: 100,
      delete_comments_on_own_questions: 750,
      edit_others_posts: 2000,
      view_offensive_counts: 2000,
      vote_to_close_any_question: 3000,
      vote_to_open_any_question: 3000,
      delete_closed_questions: 10000,
      moderate: 10000
    }
    ConstrainsConfig.create(:name => "bootstrap", :content => bootstrap_content)
  end

  desc "Reindex data"
  task :reindex => [:environment] do
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

    $stderr.puts "Reindexing #{Question.count} questions..."
    Question.all.each do |question|
      question._keywords = []
      question.rolling_back = true
      question.save(:validate => false)
    end

    $stderr.puts "Reindexing #{Answer.count} answers..."
    Answer.all.each do |answer|
      answer._keywords = []
      answer.rolling_back = true
      answer.save(:validate => false)
    end

    $stderr.puts "Reindexing #{Group.count} groups..."
    Group.all.each do |group|
      group._keywords = []
      group.save(:validate => false)
    end
  end
end

