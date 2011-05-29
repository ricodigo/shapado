require 'spec_helper'

describe Jobs::Users do
  before(:each) do
    @user = User.make
    @group = Group.make
  end

  describe "post_to_twitter" do
    before(:each) do
      @twitter_client = mock("twitter client")
      @user.should_receive(:twitter_client).and_return(@twitter_client)
      User.stub!(:find).with(@user.id).and_return(@user)
    end

    it "should be successful" do
      @twitter_client.should_receive(:update).with("something")
      lambda {Jobs::Users.post_to_twitter(@user.id, "something")}.should_not raise_error
    end
  end

  describe "on_update_user" do
    it "should be successful" do
      lambda {Jobs::Users.on_update_user(@user.id, @group.id)}.should_not raise_error
    end
  end

  describe "get_facebook_friends" do
    before(:each) do
      @facebook_client = mock("facebook client")
      @facebook_client.should_receive(:[]).with("data").and_return([])
      @user.should_receive(:facebook_client).and_return(@facebook_client)
      User.stub!(:find).with(@user.id).and_return(@user)
    end

    it "should be successful" do
      lambda {Jobs::Users.get_facebook_friends(@user.id)}.should_not raise_error
    end
  end

  describe "get_twitter_friends" do
    before(:each) do
      @twitter_client = mock("twitter client")
      @user.should_receive(:twitter_client).and_return(@twitter_client)
      @twitter_client.stub!(:friends_ids).and_return([])
      User.stub!(:find).with(@user.id).and_return(@user)
    end

    it "should be successful" do
      lambda {Jobs::Users.get_twitter_friends(@user.id)}.should_not raise_error
    end
  end

  describe "get_identica_friends" do
    before(:each) do
      @identica_client = mock("identica client")
      @user.stub!(:get_identica_friends).and_return([])
      User.stub!(:find).with(@user.id).and_return(@user)
    end

    it "should be successful" do
      lambda {Jobs::Users.get_identica_friends(@user.id)}.should_not raise_error
    end
  end

  describe "get_linked_in_friends" do
    before(:each) do
      @linkedin_client = mock("linked in client")
      @user.stub!(:get_linked_in_friends).and_return([])
      User.stub!(:find).with(@user.id).and_return(@user)
    end

    it "should be successful" do
      lambda {Jobs::Users.get_linked_in_friends(@user.id)}.should_not raise_error
    end
  end
end
