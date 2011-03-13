require 'spec_helper'

describe MobileController do

  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_redirect
    end
  end

end
