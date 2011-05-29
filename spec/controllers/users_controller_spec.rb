require 'spec_helper'

describe UsersController do
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
      get 'show', :id => @user.id
      response.should be_success
      assigns[:user].id.should == @user.id
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
#       Group.should_receive(:find_by_slug_or_id).with(@group.id).and_return(@group)
#       @user.stub!(:owner_of?).with(anything).and_return(true)
      get 'edit', :id => @user.id
      response.should be_success
    end
  end

  describe "POST 'create'" do
    before (:each) do
#       @group = stub_group
    end

    it "should be successful" do
      post 'create', :user => User.plan
      response.should redirect_to "http://test.host/"
    end
  end

  describe "PUT 'update'" do
    before (:each) do
      @user_attrs = User.plan
    end

    it "should be successful" do
      put 'update', :id => @user.id, :user => @user_attrs
      response.should redirect_to root_path
    end
  end

#   describe "DELETE 'destroy'" do
#     before (:each) do
#       @user.stub!(:admin?).and_return(true)
#     end
#
#     it "should be successful" do
#       delete 'destroy', :id => @user.id
#       response.should redirect_to users_path
#     end
#   end

  describe "GET 'autocomplete_for_user_login'" do
    before (:each) do
    end

    it "should be successful" do
      get 'autocomplete_for_user_login', :id => @user.id, :term => "", :format => :json
      response.should be_success
    end
  end


end
