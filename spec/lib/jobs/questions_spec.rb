require 'spec_helper'

describe Jobs::Questions do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make(:votes => {})
  end

  describe "on_question_solved" do
    it "should be successful" do
      answer = Answer.make(:votes => {}, :question => @question)
      lambda {Jobs::Questions.on_question_solved(@question.id, answer.id)}.should_not raise_error
    end
  end

  describe "on_question_unsolved" do
    it "should be successful" do
      answer = Answer.make(:votes => {}, :question => @question)
      lambda {Jobs::Questions.on_question_unsolved(@question.id, answer.id)}.should_not raise_error
    end
  end

  describe "on_view_question" do
    it "should be successful" do
      lambda {Jobs::Questions.on_view_question(@question.id)}.should_not raise_error
    end
  end

  describe "on_ask_question" do
    it "should be successful" do
      link = ""
      lambda {Jobs::Questions.on_ask_question(@question.id,link)}.should_not raise_error
    end
  end

  describe "on_destroy_question" do
    it "should be successful" do
      lambda {Jobs::Questions.on_destroy_question(@question.user.id, @question.attributes)}.should_not raise_error
    end
  end

  describe "on_question_followed" do
    it "should be successful" do
      lambda {Jobs::Questions.on_question_followed(@question.id)}.should_not raise_error
    end
  end

  describe "close_reward" do
    it "should be successful" do
      lambda {Jobs::Questions.close_reward(@question.id)}.should_not raise_error
    end
  end

  describe "on_start_reward" do
    it "should be successful" do
      lambda {Jobs::Questions.on_start_reward(@question.id)}.should_not raise_error
    end
  end

  describe "on_close_reward" do
    it "should be successful" do
      answer = Answer.make(:votes => {}, :question => @question)
      lambda {Jobs::Questions.on_close_reward(@question.id, answer.id, @question.user.id)}.should_not raise_error
    end
  end
end
