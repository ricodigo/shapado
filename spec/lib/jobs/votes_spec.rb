require 'spec_helper'

describe Jobs::Votes do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make(:votes => {})
    @answer = Answer.make(:votes => {}, :question => @question)
  end

  describe "on_vote_question" do
    it "should be successful" do
      lambda {Jobs::Votes.on_vote_question(@question.id, 1, @question.user.id, @question.group.id)}.should_not raise_error
    end
  end

  describe "on_vote_answer" do
    it "should be successful" do
      lambda {Jobs::Votes.on_vote_answer(@answer.id, 1, @answer.user.id, @answer.group.id)}.should_not raise_error
    end
  end
end
