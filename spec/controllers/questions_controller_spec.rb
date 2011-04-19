require 'spec_helper'

describe QuestionsController do
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
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'history', :id => @question.id
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

  describe "GET 'related_questions'" do
    before (:each) do
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'related_questions', :id => @question.id, :format => :js
      response.should be_success
    end
  end

  describe "GET 'tags_for_autocomplete'" do
    before (:each) do
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'tags_for_autocomplete', :term => @question.id, :format => :js
      response.should be_success
    end
  end

  describe "GET 'show'" do
    before (:each) do
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'show', :id => @question.id
      response.should be_success
      assigns[:question].id.should == @question.id
    end
  end

  describe "GET 'new'" do
    it "should be successful" do
      get 'new'
      response.should be_success
    end
  end

  describe "GET 'edit'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      @user.stub!(:can_edit_others_posts_on?).with(@question.group).and_return(true)
      get 'edit', :id => @question.id
      response.should be_success
    end
  end

  describe "POST 'create'" do
    before (:each) do
      @group = stub_group
    end

    it "should be successful" do
      post 'create', :question => Question.plan(:question, :user => @user)
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "PUT 'update'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @question_attrs = Question.plan(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      @question_attrs.delete("title")
      put 'update', :id => @question.id, :question => @question_attrs
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "DELETE 'destroy'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      delete 'destroy', :id => @question.id
      response.should redirect_to questions_path
    end
  end

  describe "GET 'solve'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @answer = Answer.make(:answer, :question => @question)
      @question.answers << @answer
      @question.save
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'solve', :id => @question.id, :answer_id => @answer.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end
end
