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
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'diff', :id => @question.id
      response.should be_success
    end
  end

  describe "GET 'revert'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'revert', :id => @question.id
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

    it "should be successful unlogged" do
      sign_out(@user)
      controller.stub!(:current_user).and_return(nil)
      controller.should_receive(:recaptcha_valid?).twice.and_return(true)
      post 'create', :question => Question.plan(:question),
                     :user => {:email => "anonimous@example.com"}
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

  describe "GET 'unsolve'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @answer = Answer.make(:answer, :question => @question)
      @question.answers << @answer
      @question.answer = @answer
      @question.accepted = true
      @question.save
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'unsolve', :id => @question.id, :answer_id => @answer.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "GET 'close'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
      @user.stub(:mod_of?).with{@question.group}.and_return(true)
    end

    it "should be successful" do
      get 'close', :id => @question.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "GET 'open'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'open', :id => @question.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "GET 'follow'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'follow', :id => @question.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "GET 'unfollow'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'unfollow', :id => @question.id
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "PUT 'retag_to'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @question_attrs = {:tags => ["x","y","z"]}
      stub_group(@question.group)
    end

    it "should be successful" do
      put 'retag_to', :id => @question.id, :question => @question_attrs
      response.should redirect_to question_path(:id => assigns[:question].slug)
    end
  end

  describe "GET 'retag'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      @user.stub!(:can_edit_others_posts_on?).with(@question.group).and_return(true)
      get 'retag', :id => @question.id
      response.should be_success
    end
  end

  describe "GET 'twitter_share'" do
    before (:each) do
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      cmd = mock("cmd")
      get 'twitter_share', :id => @question.id
      response.should redirect_to question_path(@question)
      assigns[:question].id.should == @question.id
    end
  end

  describe "GET 'random'" do
    before (:each) do
      @question = Question.make(:question)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'random'
      response.should redirect_to question_path(@question)
      assigns[:question].id.should == @question.id
    end
  end

  describe "GET 'remove_attachment'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      stub_group(@question.group)
    end

    it "should be successful" do
      @question.group.questions.should_receive(:by_slug).and_return(@question)
      @question.attachments.should_receive(:delete).with("attach_id")
      get 'remove_attachment', :id => @question.id, :attach_id => "attach_id"
      response.should redirect_to edit_question_path(@question)
    end
  end

  describe "GET 'move'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @user.stub!(:admin?).and_return(true)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'move', :id => @question.id
      response.should be_success
    end
  end

  describe "GET 'move_to'" do
    before (:each) do
      @question = Question.make(:question, :user => @user)
      @user.stub!(:admin?).and_return(true)
      @new_group = Group.make(:group)

      Group.stub!(:by_slug).with(@new_group.id).and_return(@new_group)
      stub_group(@question.group)
    end

    it "should be successful" do
      get 'move_to', :id => @question.id, :question => {:group => @new_group.id}
      response.should redirect_to question_path(@question)
    end
  end
end
