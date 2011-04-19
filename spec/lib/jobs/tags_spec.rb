require 'spec_helper'

describe Jobs::Tags do
  before(:each) do
    @current_user = User.make
    Thread.current[:current_user] = @current_user
    @question = Question.make
  end

  describe "question_retagged" do
    it "should be successful" do
      lambda {Jobs::Tags.question_retagged(@question.id,
                                           ["a","b","c"],
                                           ["a","b","c","d"],
                                           Time.now)}.should_not raise_error
    end
  end
end
