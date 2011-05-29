require 'spec_helper'

describe User do
  before(:each) do
    @user = User.make
  end

  describe "module/plugin inclusions (optional)" do
  end

  describe "validations" do
  end

  describe "association" do
  end

  describe "callbacks" do
  end

  describe "named scopes" do
  end

  describe "class methods" do
    describe "User#find_for_authentication" do
      it "should get the user with his login" do
        User.find_for_authentication(:email => @user.login).should == @user
      end
    end

    describe "User#find_by_login_or_id" do

      it "should return the user with his login" do
        User.find_by_login_or_id(@user.login).should == @user
      end

      it "should return the user with his id" do
        User.find_by_login_or_id(@user.login).should == @user
      end
    end

    describe "User#find_experts" do
      it("should return @user") do
        @user.preferred_languages = ["en", "es", "fr"]
        @user.save
        @stat = UserStat.make(:user => @user, :answer_tags => ["tag1"] )
        User.find_experts(["tag1"]).first.should == @user
      end

      it("should not return @user") do
        @user.preferred_languages = ["en", "es", "fr"]
        @user.save
        @stat = UserStat.make( :user => @user, :answer_tags => ["tag1"] )
        User.find_experts(["tag1"], ["en"], {:except => @user.id}).first.should_not == @user
      end
    end
  end

  describe "instance methods" do
    describe "User#membership_list" do
      it "should" do
        @user.membership_list
      end
    end

    describe "User#login=" do
      it "should downcase the login" do
        @user.login = "MEE"
        @user.login.should == "mee"
      end
    end

    describe "User#email=" do
      it "should downcase the email" do
        @user.email = "ME@example.com"
        @user.email.should == "me@example.com"
      end
    end

    describe "User#to_param" do
      it "should return the user id when the login is blank" do
        @user.login = ""
        @user.to_param.should == @user.id
      end

      it "should return the user id when the login have special charts" do
        @user.login = "jhon@doe"
        @user.to_param.should == @user.id
      end

      it "should return the user login if this have wight spaces" do
        @user.login = "jhon doe"
        @user.to_param.should == @user.login
      end
    end

    describe "User#add_preferred_tags" do
      it "should add unique tags" do
        @group = Group.make( :owner => @user)
        @user.add_preferred_tags(["a", "a", "b", "c"], @group)
        @user = User.find(@user.id)
        @user.config_for(@group).preferred_tags.should == ["a", "b", "c"]
        @group.destroy
      end
    end

    describe "User#remove_preferred_tags" do
      it "remove the tags a, b" do
        @group = Group.make(:owner => @user)
        @user.add_preferred_tags(["a", "b", "c"], @group)
        @user.reload
        @user.remove_preferred_tags(["a", "b"], @group)
        @user = User.find(@user.id)
        @user.config_for(@group).preferred_tags.should == ["c"]
        @group.destroy
      end
    end

    describe "User#preferred_tags_on" do
      it "should return a,b,c tags" do
        @group = Group.make(:owner => @user)
        @user.add_preferred_tags(["a", "b", "c"], @group)
        @user = User.find(@user.id)
        @user.preferred_tags_on(@group).should == ["a", "b", "c"]
        @group.destroy
      end
    end

    describe "User#language_filter=" do
      it "should set the language filter" do
        @user.language_filter.should == "user"
        @user.language_filter= "es"
        @user.language_filter.should == "es"
      end

      it "should not set the language filter when is not a avaible filter" do
        @user.language_filter.should == "user"
        @user.language_filter= "x"
        @user.language_filter.should_not == "x"
      end
    end

    describe "User#languages_to_filter" do
      it "should return the AVAILABLE_LANGUAGES" do
        @user.language_filter="any"
        @user.languages_to_filter.should == AVAILABLE_LANGUAGES
      end

      it "should return the user's preferred languages" do
        @user.language_filter="user"
        @user.preferred_languages = ["en", "es"]
        @user.languages_to_filter.should == @user.preferred_languages
      end

      it "should return the user's language filter" do
        @user.language_filter="es"
        @user.languages_to_filter.should == ["es"]
      end
    end

    describe "User#is_preferred_tag?" do
      it "should return the tag" do
        @group = Group.make(:owner => @user)
        @user.add_preferred_tags(["a", "b", "c"], @group)
        @user = User.find(@user.id)
        @user.is_preferred_tag?(@group, "a").should == "a"
        @group.destroy
      end
    end

    describe "User#admin?" do
      it "should return true when the user's role is admin" do
        @user.role = "admin"
        @user.admin?.should == true
      end

      it "should return false when the user's role is not admin" do
        @user.role = "user"
        @user.admin?.should == false
      end
    end

    describe "User#age" do
      it "should return 18" do
        @user.birthday = 18.years.ago
        @user.age == 18
      end
    end

    describe "User#can_modify?" do
      it "should can modify the question" do
        Activity.stub!(:create!)
        @question = Question.make(:user => @user)
        @user.can_modify?(@question)
      end
    end

    describe "User#can_create_reward?" do
      it "return true when the question was created more than 2 days ago" do
        Activity.stub!(:create!)
        @question = Question.make(:user => @user, :created_at => 3.days.ago)
        @user.update_reputation(76, @question.group)
        @user.reload
        @user.can_create_reward?(@question).should == true
      end
    end

    describe "User#groups" do
    end

    describe "User#member_of?" do
    end

    describe "User#role_on" do

    end

    describe "User#owner_of?" do
    end

    describe "User#mod_of?" do
    end

    describe "User#editor_of?" do
    end

    describe "User#user_of?" do
    end

    describe "User#main_language" do
    end

    describe "User#openid_login?" do
    end

    describe "User#twitter_login?" do
    end

    describe "User#has_voted?" do
    end

    describe "User#vote_on" do
    end

    describe "User#favorite?" do
    end

    describe "User#favorite" do
    end

    describe "User#logged!" do
    end

    describe "User#on_activity" do
    end

    describe "User#activity_on" do
    end

    describe "User#reset_activity_days!" do
    end

    describe "User#upvote!" do
    end

    describe "User#downvote!" do
    end

    describe "User#update_reputation" do
    end

    describe "User#reputation_on" do
    end

    describe "User#stats" do
    end

    describe "User#badges_count_on" do
    end

    describe "User#badges_on" do
    end

    describe "User#find_badge_on" do
    end

    describe "User#add_friend" do
    end

    describe "User#remove_friend" do
    end

    describe "User#followers" do
    end

    describe "User#following" do
    end

    describe "User#following?" do
    end

    describe "User#viewed_on!" do
    end

    describe "User#config_for" do
    end

    describe "User#reputation_stats" do
    end

    describe "User#has_flagged?" do
    end

    describe "User#has_requested_to_close?" do
    end

    describe "User#has_requested_to_open?" do
    end

    describe "User#generate_uuid" do
    end
  end
end
