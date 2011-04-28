require 'spec_helper'

describe VotesController do
  include Devise::TestHelpers

  before (:each) do
    stub_group
    @group = Group.make(:group)
    @user = User.make(:user)
    stub_authentication @user
    @voteable = Question.make(:question, :group => @group)
  end

  describe "GET 'index'" do
    it "should redirect to root path" do
      get 'index'
      response.should redirect_to root_path
    end
  end

  describe "POST 'create'" do
    before (:each) do
      stub_group(@voteable.group)
      @vote_attrs = {:vote_up => 1}
    end

    it "should be successful" do
      @vote_attrs.merge!(:question_id => @voteable.id)
      post 'create', @vote_attrs
      response.should redirect_to root_path
    end

    it "should be successful for js format" do
      @vote_attrs.merge!(:question_id => @voteable.id, :format => "js")
      post 'create', @vote_attrs
      response.should be_success
    end
  end
end
