require 'spec_helper'

describe Answer do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @answer = Answer.make(:votes => {})
  end

  describe "module/plugin inclusions (optional)" do
  end

  describe "validations" do
    it "the answer of a user in a question should be unique" do
      answer = Answer.make_unsaved(:question => @answer.question,
                                   :created_at => @answer.created_at+1.day,
                                   :user => @answer.user,
                                   :group_id => @answer.group_id,
                                   :votes => {})

      answer.valid?.should be_false
      answer.errors[:limitation].should_not be_nil
    end

    it "elapsed time between two answers by the same user should be greater than 20 secs" do
      answer = Answer.make_unsaved(:question => @answer.question,
                                   :created_at => @answer.created_at+1,
                                   :user => @answer.user,
                                   :group => @answer.group,
                                   :votes => {})
      answer.valid?.should be_false
    end
  end

  describe "association" do
  end

  describe "callbacks" do
    describe "Answer#unsolve_question" do
      it "should set the answer's question as unsolved when the question is deleted" do
        question = @answer.question
        question.answer = @answer
        question.accepted = true
        question.save
        question.reload

        question.accepted.should be_true
        question.answer.should_not be_nil

        @answer.destroy

        question.reload
        question.accepted.should be_false
        question.answer.should be_nil
      end
    end
  end

  describe "named scopes" do
  end

  describe "class methods" do
    describe "Answer#minimal" do
      it "should return a answer context without some keys" do
        Answer.should_receive(:without).with(:_keywords,
                                             :flags,
                                             :votes,
                                             :versions)
        Answer.minimal
      end
    end

    describe "Answer#ban" do
      it "should ban the answer" do
        @answer.banned.should be_false
        Answer.ban([@answer.id])
        @answer.reload
        @answer.banned.should be_true
      end
    end

    describe "Answer#unban" do
      it "should unban the answer" do
        @answer.ban
        @answer.reload
        Answer.unban([@answer.id])
        @answer.reload
        @answer.banned.should be_false
      end
    end
  end

  describe "instance methods" do
    describe "Answer#ban" do
      it "should ban the answer" do
        @answer.banned.should be_false
        @answer.ban
        @answer.reload
        @answer.banned.should be_true
      end
    end

    describe "Answer#unban" do
      it "should unban the answer" do
        @answer.ban
        @answer.unban
        @answer.reload
        @answer.banned.should be_false
      end
    end

    describe "Answer#can_be_deleted_by?" do
      before(:each) do
        @user = User.make
        @answer.question.closed = true
      end

      after(:each) do
        @user.destroy
      end

      describe "should return true when the user " do
        it "is the answer's creator and he can delete his own comments" do
          @answer.user.should_receive(:can_delete_own_comments_on?).with(anything).and_return(true)
          @answer.can_be_deleted_by?(@answer.user).should == true
        end

        it "is the question's creator and he can delete comments on his own questions" do
          user = @answer.question.user
          user.should_receive(:can_delete_comments_on_own_questions_on?).
                                with(anything).and_return(true)
          @answer.can_be_deleted_by?(user).should == true
        end
      end
    end

    describe "Answer#on_add_vote" do
    end

    describe "Answer#on_remove_vote" do
    end

    describe "Answer#flagged!" do
      it "should increment the answer's flags counter" do
        @answer.flags_count.should == 0
        @answer.flagged!
        @answer.reload
        @answer.flags_count.should == 1
      end
    end

    describe "Answer#to_html" do
    end

    describe "Answer#disable_limits?" do
    end

    describe "Answer#add_favorite!" do
    end

    describe "Answer#remove_favorite!" do
    end

    describe "Answer#favorite_for?" do
    end
  end
end
