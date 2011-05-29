require 'spec_helper'

describe Jobs::Activities do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make(:votes => {})
    @answer = Answer.make(:votes => {}, :question => @question)
  end

  describe "on_activity" do
    it "should be successful" do
      lambda {Jobs::Activities.on_activity(@question.group.id, @question.user.id)}.should_not raise_error
    end
  end

  describe "on_update_answer" do
    it "should be successful" do
      @answer.updated_by = @answer.user
      @answer.save
      lambda {Jobs::Activities.on_update_answer(@answer.id)}.should_not raise_error
    end
  end

  describe "on_create_answer" do
    it "should be successful" do
      lambda {Jobs::Activities.on_create_answer(@answer.id)}.should_not raise_error
    end
  end

  describe "on_destroy_answer" do
    it "should be successful" do
      lambda {Jobs::Activities.on_destroy_answer(@answer.user.id, @answer.attributes)}.should_not raise_error
    end
  end

  describe "on_comment" do
    it "should be successful" do
      @comment = Comment.make(:commentable => @answer)
      @answer.comments << @comment
      @answer.save
      lambda {Jobs::Activities.on_comment(@answer.id, @answer.class.to_s, @comment.id)}.should_not raise_error
    end
  end

  describe "on_follow" do
    it "should be successful" do
      lambda {Jobs::Activities.on_follow(@question.user.id, @answer.user.id, @answer.group.id)}.should_not raise_error
    end
  end

  describe "on_unfollow" do
    it "should be successful" do
      lambda {Jobs::Activities.on_unfollow(@question.user.id, @answer.user.id, @answer.group.id)}.should_not raise_error
    end
  end

  describe "on_flag" do
    it "should be successful" do
      lambda {Jobs::Activities.on_flag(@question.user.id, @question.group.id, "spam")}.should_not raise_error
    end
  end

  describe "on_rollback" do
    it "should be successful" do
      @question.updated_by = @answer.user
      @question.save
      lambda {Jobs::Activities.on_rollback(@question.id)}.should_not raise_error
    end
  end

  describe "on_admin_connect" do
    it "should be successful" do
      lambda {Jobs::Activities.on_admin_connect("192.168.0.2", @answer.user.id)}.should_not raise_error
    end
  end
end
