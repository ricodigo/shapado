require 'spec_helper'

describe CloseRequestsController do
  include Devise::TestHelpers

  before (:each) do
    @group = stub_group
    @user = User.make(:user)
    stub_authentication @user
    Activity.stub!(:create!)
    @question = Question.make(:question)
    @group.questions.stub!(:find_by_slug_or_id).with(@question.id).and_return(@question)
  end

  describe "GET 'index'" do
    it "should be successful" do
      @user.stub!(:admin?).and_return(true)
      get 'index', :question_id => @question.id
      response.should be_success
    end
  end

  describe "GET 'new'" do
    it "should be successful" do
      get 'new', :question_id => @question.id
      response.should be_success
    end
  end

  describe "POST 'create'" do
    before (:each) do
    end

    it "should be successful" do
      post 'create', :question_id => @question.id, :close_request => CloseRequest.plan(:close_request, :user => @user)
      response.should redirect_to question_path(:id => @question.slug)
    end
  end

  describe "PUT 'update'" do
    before (:each) do
      @close_request = CloseRequest.make(:close_request, :user => @user, :question => @question)
      @close_request_attrs = CloseRequest.plan(:close_request, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      put 'update', :id => @close_request.id, :question_id => @question.id,  :close_request => @close_request_attrs
      response.should redirect_to question_path(:id => @question.slug)
    end
  end

  describe "DELETE 'destroy'" do
    before (:each) do
      @close_request = CloseRequest.make(:close_request, :user => @user, :question => @question)
    end

    it "should be successful" do
      delete 'destroy', :id => @close_request.id, :question_id => @question.id
      response.should redirect_to question_path(:id => @question.slug)
    end
  end
end
