require 'spec_helper'

describe Question do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make(:votes => {})
  end

  describe "module/plugin inclusions (optional)" do
  end

  describe "validations" do
    it "should have a title" do
      @question.title = ""
      @question.valid?.should == false
    end

    it "should have a creator(user)" do
      @question.user = nil
      @question.valid?.should be_false
    end

    it "question slug should unique" do
      question = Question.make_unsaved(:title => @question.title)
      question.slug = @question.slug
      question.group = @question.group
      question.valid?.should == false
    end

    describe "check useful" do
      before(:each) do
        @question.stub!(:disable_limits?).and_return(false)
      end

      it "should be invalid for a short title" do
          @question.title = "too short"
          @question.valid?.should be_false
          @question.errors[:title].should_not be_nil
      end

      it "should be invalid for a short body" do
          @question.body = "too short"
          @question.valid?.should be_false
          @question.errors[:body].should_not be_nil
      end
    end

    describe "check spam" do
      before(:each) do
        @question.stub!(:disable_limits?).and_return(false)
      end

      it "should be invalid when the have ask a question 20 seconds ago" do
        new_question = Question.make_unsaved( :user => @question.user,
                                              :group => @question.group)
        new_question.stub!(:disable_limits?).and_return(false)
        new_question.valid?.should be_false
        new_question.errors[:body].should_not be_nil
      end
    end
  end

  describe "association" do
  end

  describe "callbacks" do
  end

  describe "named scopes" do
  end

  describe "class methods" do
    describe "Question#related_questions" do
      it "should get the related questions with for a question with tag generate" do
        Question.related_questions(Question.make(:tags => ["generate"]))
      end
    end

    describe "Question#ban" do
      it "should ban the question" do
        @question.banned.should be_false
        Question.ban([@question.id])
        @question.reload
        @question.banned.should be_true
      end
    end

    describe "Question#unban" do
      it "should unban the question" do
        @question.ban
        @question.reload
        Question.unban([@question.id])
        @question.reload
        @question.banned.should be_false
      end
    end
  end

  describe "instance methods" do
    describe "Question#first_tags" do
      it "should get the first_tags(6)" do
        @question.user.stub(:can_create_new_tags_on?).with(anything).and_return(true)
        @question.tags = %w[a b c d e f g]
        @question.first_tags.should == %w[a b c d e f]
        @question.first_tags.size == 6
      end
    end

    describe "Question#tags=" do
      before(:each) do
        @question.user.stub(:can_create_new_tags_on?).with(anything).and_return(true)
      end

      it "should convert the string separted by comas in an array" do
        @question.tags = "apples,oranges"
        @question.tags.should == %w[apples oranges]
      end

      it "should convert the string separted by comas,spaces and + in an array" do
        @question.tags = "apples,oranges mango+passion-fruit"
        @question.tags.should == %w[apples oranges mango passion-fruit]
      end
    end

    describe "Question#viewed!" do
      it "should increment the question's view count" do
        @question.views_count.should == 0
        @question.viewed!("127.0.0.0")
        @question.views_count.should == 1
      end

      it "should not increment the question's view count" do
        @question.viewed!("127.0.0.0")
        @question.views_count.should == 1
        @question.viewed!("127.0.0.0")
        @question.views_count.should == 1
      end
    end

    describe "Question#answer_added!" do
      it "should increment the question's answer counter" do
        @question.should_receive(:on_activity)
        @question.answers_count.should == 0
        @question.answer_added!
        @question.answers_count.should == 1
      end
    end

    describe "Question#answer_removed!" do
      it "should decrement the question's answer counter" do
        @question.should_receive(:on_activity)
        @question.answer_added!
        @question.answers_count.should == 1
        @question.answer_removed!
        @question.reload
        @question.answers_count.should == 0
      end
    end

    describe "Question#flagged!" do
      it "should increment the question's flags counter" do
        @question.flags_count.should == 0
        @question.flagged!
        @question.flags_count.should == 1
      end
    end

    describe "Question#on_add_vote" do
      before(:each) do
        @question.stub!(:on_activity)
        @voter = User.make_unsaved
        @voter.stub!(:on_activity)
        @question.user.stub!(:update_reputation)
      end

      describe "should update question's user reputation with" do
        it "question_receives_up_vote" do
          @question.user.should_receive(:update_reputation).
                            with(:question_receives_up_vote, anything)
          @question.on_add_vote(1, @voter)
        end

        it "question_receives_down_vote" do
          @question.user.should_receive(:update_reputation).
                            with(:question_receives_down_vote, anything)
          @question.on_add_vote(-1, @voter)
        end
      end

      describe "should report activity by voter for" do
        it "vote_up_question" do
          @voter.should_receive(:on_activity).with(:vote_up_question, anything)
          @question.on_add_vote(1, @voter)
        end

        it "vote_down_question" do
          @voter.should_receive(:on_activity).with(:vote_down_question, anything)
          @question.on_add_vote(-1, @voter)
        end
      end
    end

    describe "Question#on_remove_vote" do
      before(:each) do
        @question.stub!(:on_activity)
        @voter = User.make_unsaved
        @voter.stub!(:on_activity)
        @question.user.stub!(:update_reputation)
      end

      describe "should update question's user reputation with" do
        it "question_undo_up_vote" do
          @question.user.should_receive(:update_reputation).
                            with(:question_undo_up_vote, anything)
          @question.on_remove_vote(1, @voter)
        end

        it "question_undo_down_vote" do
          @question.user.should_receive(:update_reputation).
                            with(:question_undo_down_vote, anything)
          @question.on_remove_vote(-1, @voter)
        end
      end

      describe "should report activity by voter for" do
        it "undo_vote_up_question" do
          @voter.should_receive(:on_activity).with(:undo_vote_up_question, anything)
          @question.on_remove_vote(1, @voter)
        end

        it "undo_vote_down_question" do
          @voter.should_receive(:on_activity).with(:undo_vote_down_question, anything)
          @question.on_remove_vote(-1, @voter)
        end
      end
    end

    describe "Question#on_activity" do
      it "should increment the question hotness" do
        @question.hotness.should == 0
        @question.on_activity
        @question.hotness.should == 1
      end

      it "should not call update_activity_at" do
        @question.should_not_receive(:update_activity_at)
        @question.on_activity(false)
      end
    end

    describe "Question#update_activity_at" do
      before(:each) do
        @current_time = Time.now
        Time.stub!(:now).and_return(@current_time)
        @question.override(:activity_at => Time.now.yesterday)
        @question.reload
      end

      it "should override the last activity date to the current time" do
        @question.activity_at.strftime("%D %T").should_not == @current_time.utc.strftime("%D %T")
        @question.update_activity_at
        @question.reload
        @question.activity_at.strftime("%D %T").should == @current_time.utc.strftime("%D %T")
      end

      it "should set the last activity date to the current time" do
        @question.stub(:new_record?).and_return(true)
        @question.activity_at.strftime("%D %T").should_not == @current_time.utc.strftime("%D %T")
        @question.update_activity_at
        @question.activity_at.strftime("%D %T").should == @current_time.utc.strftime("%D %T")
      end
    end

    describe "Question#ban" do
      it "should ban the question" do
        @question.banned.should be_false
        @question.ban
        @question.reload
        @question.banned.should be_true
      end
    end

    describe "Question#unban" do
      it "should unban the question" do
        @question.ban
        @question.unban
        @question.reload
        @question.banned.should be_false
      end
    end

    describe "Question#add_follower" do
      before(:each) do
        @follower = User.make
        @question.stub(:follower?).and_return(false)
      end

      after(:each) do
        @follower.destroy
      end

      it "should add @follower as question's follower" do
        @question.add_follower(@follower)
        @question.reload
        @question.followers_count.should == 1
        @question.followers.map(&:id).should include @follower.id
      end

      it "should not @follower as question's follower" do
        @question.should_receive(:follower?).and_return(true)
        @question.add_follower(@follower)
        @question.reload
        @question.followers_count.should == 0
        @question.followers.should_not include @follower.id
      end
    end


    describe "Question#remove_follower" do
      before(:each) do
        @follower = User.make
        @question.add_follower(@follower)
        @question.reload
        @question.stub(:follower?).and_return(true)
      end

      it "follower add @follower as question's follower" do
        @question.remove_follower(@follower)
        @question.reload
        @question.followers_count.should == 0
        @question.followers.should_not include @follower.id
      end
    end

    describe "Question#follower?" do
      before(:each) do
        @follower = User.make
        @question.add_follower(@follower)
        @question.reload
      end

      after(:each) do
        @follower.destroy
      end

      it "should return true for @follower" do
        @question.follower?(@follower).should be_true
      end

      it "should return false for a new user" do
        @question.follower?(User.make).should be_false
      end
    end

    describe "Question#disable_limits?" do
      describe "if question's user can post whithout limits should return" do
        it "true" do
          @question.user.should_receive(:can_post_whithout_limits_on?).with(anything).and_return(true)
          @question.disable_limits?.should == true
        end

        it "false" do
          @question.user.should_receive(:can_post_whithout_limits_on?).with(anything).and_return(false)
          @question.disable_limits?.should == false
        end
      end
    end

    describe "Question#answered" do
      it "should return true if answered_with_id is present" do
        @question.answered_with = Answer.make( :question => @question,
                                               :group => @question.group)
        @question.answered.should be_true
      end
    end

    describe "Question#update_last_target" do
      before(:each) do
        @target = Answer.make(:question => @question, :group => @question.group)
      end

      it "should set the las target propieties" do
        @question.update_last_target(@target)
        @question.reload
        @question.last_target_id.should == @target.id
        @question.last_target_user_id.should == @target.user_id
        @question.last_target_type.should == @target.class.to_s
        @question.last_target_date == @target.updated_at.utc
      end
    end

    describe "Question#can_be_requested_to_close_by?" do
      it "should return false when the question is closed" do
        @question.closed = true
        @question.can_be_requested_to_close_by?(@question.user)
      end

      describe "should return true when the user " do
        before(:each) do
          @user = User.make
        end

        after(:each) do
          @user.destroy
        end

        it "is the question owner and can vote to close his own question" do
          @question.user.should_receive(:can_vote_to_close_own_question_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_requested_to_close_by?(@question.user)
        end

        it "can vote to close any question" do
          @user.should_receive(:can_vote_to_close_any_question_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_requested_to_close_by?(@user)
        end
      end
    end

    describe "Question#can_be_requested_to_open_by?" do
      it "should return false when the question is open" do
        @question.closed = false
        @question.can_be_requested_to_open_by?(@question.user)
      end

      describe "should return true when the user " do
        before(:each) do
          @user = User.make
          @question.closed = true
        end

        after(:each) do
          @user.destroy
        end

        it "is the question owner and can vote to open his own question" do
          @question.user.should_receive(:can_vote_to_open_own_question_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_requested_to_open_by?(@question.user)
        end

        it "can vote to open any question" do
          @user.should_receive(:can_vote_to_open_any_question_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_requested_to_open_by?(@user)
        end
      end
    end

    describe "Question#can_be_deleted_by?" do
      before(:each) do
        @user = User.make
        @question.closed = true
      end

      after(:each) do
        @user.destroy
      end

      describe "should return false when " do
        it "the user is the question owner and the question have answers" do
          @target = Answer.make(:question => @question, :group => @question.group)
          @question.can_be_deleted_by?(@question.user).should == false
        end

        it "the question is not closed" do
          @question.closed = false
          @user.stub!(:can_delete_closed_questions_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_deleted_by?(@user).should == false
        end

        it "the question is closed and the can't delete closed questions" do
          @question.closed = true
          @user.should_receive(:can_delete_closed_questions_on?).
                                                            with(anything).
                                                            and_return(false)
          @question.can_be_deleted_by?(@user).should == false
        end
      end

      describe "should return true when the user " do
        it "is the question owner and the question doesn't have answers" do
          @question.can_be_deleted_by?(@question.user).should == true
        end

        it "the user can delete closed questions and the question is closed" do
          @question.closed = true
          @user.should_receive(:can_delete_closed_questions_on?).
                                                            with(anything).
                                                            and_return(true)
          @question.can_be_deleted_by?(@user)
        end
      end
    end

    describe "Question#close_reason" do
      it "should return nil" do
        @question.close_reason.should be_nil
      end

      it "should return @close_reason" do
        @question.user.stub!(:can_vote_to_close_any_question_on?).
                                                            with(anything).
                                                            and_return(true)
        @close_request = CloseRequest.make( :user => @question.user,
                                            :reason => "dupe")
        @close_request.closeable = @question
        @close_request.save
        @question.close_reason_id = @close_request.id
        @question.save
        @question.reload
        @question.close_reason.id.should == @close_request.id
      end
    end

    describe "Question#last_target=" do
      before(:each) do
        @target = Answer.make(:question => @question, :group => @question.group)
      end

      it "should set the las target propieties" do
        @question.last_target = @target
        @question.last_target_id.should == @target.id
        @question.last_target_user_id.should == @target.user_id
        @question.last_target_type.should == @target.class.to_s
        @question.last_target_date == @target.updated_at.utc
      end
    end
  end
end
