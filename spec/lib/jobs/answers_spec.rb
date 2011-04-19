require 'spec_helper'

describe Jobs::Answers do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make(:votes => {})
    @answer = Answer.make(:votes => {}, :question => @question)
  end

  describe "on_favorite_answer" do
    it "should be successful" do
#       lambda {Jobs::Answers.on_favorite_answer(@answer_id, favoriter_id, link)}.should_not raise_error
    end
  end

  describe "on_create_answer" do
    it "should be successful" do
      link = ""
      lambda {Jobs::Answers.on_create_answer(@question.id, @answer.id, link)}.should_not raise_error
    end
  end
end
