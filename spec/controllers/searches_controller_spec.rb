require 'spec_helper'

describe SearchesController do
  include Devise::TestHelpers

  before (:each) do
    @group = stub_group
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
      @search = Search.make(:user => @user, :group => @group)
    end

    it "should be successful" do
      get 'show', :id => @search.id
      response.should be_success
      assigns[:search].id.should == @search.id
    end
  end

  describe "POST 'create'" do
    before (:each) do
      @group = stub_group
    end

    it "should be successful" do
      post 'create', :search => Search.plan(:search, :user => @user)
      response.should redirect_to search_path(assigns[:search])
    end
  end

  describe "DELETE 'destroy'" do
    before (:each) do
      @search = Search.make(:user => @user, :group => @group)
    end

    it "should be successful" do
      delete 'destroy', :id => @search.id
      response.should redirect_to root_path
    end
  end
end
