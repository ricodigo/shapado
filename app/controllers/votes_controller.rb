class VotesController < ApplicationController
  before_filter :find_voteable
  before_filter :check_permissions, :except => [:index]


  def index
    redirect_to(root_path)
  end

  # TODO: refactor
  def create
    value = 0
    if params[:vote_up] || params['vote_up.x'] || params['vote_up.y']
      value = 1
    elsif params[:vote_down] || params['vote_down.x'] || params['vote_down.y']
      vote_type = "vote_down"
      value = -1
    end

    state = :error
    if validate_vote(value, current_user)
      state = @voteable.vote(value, current_user)
      flash[:notice] = generate_notice(state)
    end

    if state == :created
      if @voteable.class == Question
        sweep_question(vote.voteable)
        Jobs::Votes.async.on_vote_question(@voteable.id, value, current_user.id, current_group.id).commit!
      elsif @voteable.class == Answer
        Jobs::Votes.async.on_vote_answer(@voteable.id, value, current_user.id, current_group.id).commit!
      end
    end

    respond_to do |format|
      format.html{redirect_to params[:source]||root_path}

      format.js do
        if state != :error
          average = @voteable.votes_average + value
          render(:json => {:success => true,
                           :message => flash[:notice],
                           :vote_type => vote_type,
                           :vote_state => state,
                           :average => I18n.t("votes.create.average", :count => average)}.to_json)
        else
          render(:json => {:success => false, :message => flash[:error] }.to_json)
        end
      end

      format.json do
        if vote_state != :error
          average = @voteable.votes_average + value
          render(:json => {:success => true,
                           :message => flash[:notice],
                           :vote_type => vote_type,
                           :vote_state => state,
                           :average => average}.to_json)
        else
          render(:json => {:success => false, :message => flash[:error] }.to_json)
        end
      end
    end
  end

  protected
  def find_voteable
    if params[:answer_id]
      @voteable = current_group.answers.find(params[:answer_id])
    elsif params[:question_id]
      @voteable = current_group.questions.find_by_slug_or_id(params[:question_id])
    end

    if params[:comment_id]
      @voteable = @voteable.comments.find(params[:comment_id])
    end
  end

  def validate_vote(value, voter)
    if value > 0
      unless voter.can_vote_up_on?(@voteable.group)
        reputation = @voteable.group.reputation_constrains["vote_up"]
        flash[:error] = I18n.t("users.messages.errors.reputation_needed",
                               :min_reputation => reputation,
                               :action => I18n.t("users.actions.vote_up"))
        return false
      end
    else
      unless voter.can_vote_down_on?(@voteable.group)
        reputation = @voteable.group.reputation_constrains["vote_down"]
        flash[:error] = I18n.t("users.messages.errors.reputation_needed",
                               :min_reputation => reputation,
                               :action => I18n.t("users.actions.vote_down"))
        return false
      end
    end

    if @voteable.user == voter
      error = I18n.t(:flash_error, :scope => "votes.create") + " "
      error += @voteable.class.human_name.downcase
      flash[:error] = error
      return false
    end

    if value < 0 && @voteable.is_a?(Comment)
      return false
    end

    valid = true
    error_message = ""
    case @voteable.class.to_s
    when "Question"
      valid = !@voteable.closed
      error_message = I18n.t("votes.model.messages.closed_question")
    when "Answer"
      valid = !@voteable.question.closed
      error_message = I18n.t("votes.model.messages.closed_question")
    when "Comment"
      valid = value > 0
      unless valid
        error_message = I18n.t("votes.model.messages.vote_down_comment")
      else
        case @voteable.commentable.class
        when Question
          valid = !@voteable.commentable.closed
          error_message = I18n.t("votes.model.messages.closed_question")
         when Answer
          valid = !@voteable.commentable.question.closed
          error_message = I18n.t("votes.model.messages.closed_question")
        end
      end
    end
    if !valid
      flash[:error] = error_message
    end
    return valid
  end

  def generate_notice(state)
    case state
      when :created
        t("votes.create.flash_notice")
      when :updated
        t("votes.create.flash_notice")
      when :destroyed
        t("votes.destroy.flash_notice")
    end
  end

  def check_permissions
    unless logged_in?
      flash[:error] = t(:unauthenticated, :scope => "votes.create")
      respond_to do |format|
        format.html do
          flash[:error] += ", [#{t("global.please_login")}](#{new_user_session_path})"
          redirect_to params[:source]
        end
        format.json do
          flash[:error] = t("global.please_login")
          render(:json => {:status => :unauthenticate, :success => false, :message => flash[:error] }.to_json)
        end
        format.js do
          flash[:error] = t("global.please_login")
          render(:json => {:status => :unauthenticate, :success => false, :message => flash[:error] }.to_json)
        end
      end
    end
  end
end
