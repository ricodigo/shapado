require 'spec_helper'

describe AnswersController do
  include Devise::TestHelpers

  before (:each) do
    stub_group
    @user = User.make(:user)
    stub_authentication @user
  end

  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'history'" do
    before (:each) do
      @question = Question.make(:question)
      @answer = Answer.make(:answer, :question => @question, :group => @question.group)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'history', :id => @answer.id
      response.should be_success
    end
  end

  describe "GET 'diff'" do
    before (:each) do
    end

    it "should be successful" do
      pending
      response.should be_success
    end
  end

  describe "GET 'revert'" do
    before (:each) do
    end

    it "should be successful" do
      pending
      response.should be_success
    end
  end

  describe "GET 'show'" do
    before (:each) do
      @question = Question.make(:question)
      @answer = Answer.make(:answer, :question => @question, :group => @question.group)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'show', :id => @answer.id, :question_id => @question.id
      response.should be_success
      assigns[:answer].id.should == @answer.id
    end
  end

#   describe "GET 'new'" do
#     before (:each) do
#       @question = Question.make(:question)
#       stub_group(@question.group)
#     end
#
#     it "should be successful" do
#       get 'new', :question_id => @question.id
#       response.should be_success
#     end
#   end

  describe "GET 'edit'" do
    before (:each) do
      @question = Question.make(:question)
      @answer = Answer.make(:answer,
                            :question => @question,
                            :group => @question.group)
      stub_group(@question.group)
    end

    it "should be successful" do
      @answer.user = @user
      @answer.save
      get 'edit', :id => @answer.id, :question_id => @question.id
      response.should be_success
    end
  end

  describe "POST 'create'" do
    before (:each) do
      @question = Question.make(:question)
      @answer = Answer.make(:answer,
                            :question => @question,
                            :group => @question.group)
      stub_group(@question.group)
    end

    it "should be successful" do
      post 'create', :question_id => @question.id, :answer => Answer.plan(:answer, :user => @user)
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "PUT 'update'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @answer = Answer.make(:answer,
                            :question => @question,
                            :group => @question.group)
      @answer_attrs = Answer.plan(:answer, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      put 'update', :id => @answer.id, :question_id => @question.id, :answer => @question_attrs
      response.should redirect_to question_path(:id => @question.slug)
    end
  end

  describe "DELETE 'destroy'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @answer = Answer.make(:answer,
                            :question => @question,
                            :group => @question.group)
      stub_group(@question.group)
    end

    it "should be successful" do
      delete 'destroy', :id => @answer.id, :question_id => @question.id
      response.should redirect_to question_path(:id => @question.slug)
    end
  end
end
