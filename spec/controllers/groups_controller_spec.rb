require 'spec_helper'

describe GroupsController do
  include Devise::TestHelpers

  before (:each) do
    stub_group
    @group = Group.make(:group)
    @user = User.make(:user)
    stub_authentication @user
  end

  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'show'" do
    before (:each) do
    end

    it "should be successful" do
      get 'show', :id => @group.id
      response.should be_success
      assigns[:group].id.should == @group.id
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
    end

    it "should be successful" do
      Group.should_receive(:find_by_slug_or_id).with(@group.id).and_return(@group)
      @user.stub!(:owner_of?).with(anything).and_return(true)
      get 'edit', :id => @group.id
      response.should be_success
    end
  end

  describe "POST 'create'" do
    before (:each) do
#       @group = stub_group
    end

    it "should be successful" do
      post 'create', :group => Group.plan(:group, :user => @user)
      response.should redirect_to "http://#{assigns[:group].domain}/manage/properties"
    end
  end

  describe "PUT 'update'" do
    before (:each) do
      @group_attrs = Group.plan(:group, :user => @user)
    end

    it "should be successful" do
      put 'update', :id => @group.id, :group => @group_attrs
      response.should redirect_to group_path(:id => assigns[:group].slug)
    end
  end

  describe "DELETE 'destroy'" do
    before (:each) do
      @user.stub!(:admin?).and_return(true)
    end

    it "should be successful" do
      delete 'destroy', :id => @group.id
      response.should redirect_to groups_path
    end
  end

  describe "GET 'accept'" do
    before (:each) do
      @user.stub!(:admin?).and_return(true)
    end

    it "should be successful" do
      get 'accept', :id => @group.id
      response.should redirect_to group_path(:id => assigns[:group].slug)
    end
  end

  describe "GET 'close'" do
    before (:each) do
    end

    it "should be successful" do
      get 'close', :id => @group.id
      response.should redirect_to group_path(:id => assigns[:group].slug)
    end
  end

  describe "GET 'autocomplete_for_group_slug'" do
    before (:each) do
    end

    it "should be successful" do
      get 'autocomplete_for_group_slug', :id => @group.id, :term => "", :format => :json
      response.should be_success
    end
  end

  describe "GET 'allow_custom_ads'" do
    before (:each) do
      @user.stub!(:admin?).and_return(true)
    end

    it "should be successful" do
      get 'allow_custom_ads', :id => @group.id
      response.should redirect_to groups_path
    end
  end

  describe "GET 'disallow_custom_ads'" do
    before (:each) do
      @user.stub!(:admin?).and_return(true)
    end

    it "should be successful" do
      get 'disallow_custom_ads', :id => @group.id
      response.should redirect_to groups_path
    end
  end

  describe "GET 'group_twitter_request_token'" do
    before (:each) do
    end

    it "should be successful" do
      pending
      get 'group_twitter_request_token', :id => @group.id
    end
  end

  describe "GET 'disconnect_twitter_group'" do
    before (:each) do
    end

    it "should be successful" do
      pending
      get 'disconnect_twitter_group', :id => @group.id
    end
  end
end
