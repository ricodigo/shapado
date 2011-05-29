class OpenRequestsController < ApplicationController
  before_filter :login_required
  before_filter :moderator_required, :only => [:index]
  before_filter :find_question
  before_filter :check_permissions, :except => [:create, :new, :index]

  def index
    @open_requests = @question.open_requests
  end

  def create
    @open_request = OpenRequest.new(:comment => params[:open_request][:comment])
    @open_request.user = current_user

    @question.open_requests << @open_request

    respond_to do |format|
      if @open_request.valid?
        @question.save  # FIXME: use modifiers
        @question.increment(:open_requests_count => 1)
        flash[:notice] = t(:flash_notice, :scope => "open_requests.create")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @open_request.to_json, :status => :created}
        format.js { render :json => {:message => flash[:notice], :success => true }.to_json }
      else
        flash[:error] = @open_request.errors.full_messages.join(", ")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @open_request.errors, :status => :unprocessable_entity}
        format.js { render :json => {:message => flash[:error], :success => false }.to_json }
      end
    end
  end

  def update
    @open_request = @question.open_requests.find(params[:id])
    @open_request.comment = params[:open_request][:comment]

    respond_to do |format|
      if @open_request.valid?
        @question.save
        flash[:notice] = t(:flash_notice, :scope => "open_requests.update")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @open_request.to_json }
        format.js { render :json => {:message => flash[:notice], :success => true }.to_json }
      else
        flash[:error] = @open_request.errors.full_messages.join(", ")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @open_request.errors, :status => :unprocessable_entity}
        format.js { render :json => {:message => flash[:error], :success => false }.to_json }
      end
    end
  end

  def destroy
    @open_request = @question.open_requests.find(params[:id])
    if @question.closed && @question.close_reason_id == @open_request.id
      @question.closed = false
    end

    @open_request.destroy
    @question.decrement(:open_requests_count => 1)
    @question.save
    flash[:notice] = t(:flash_notice, :scope => "open_requests.destroy")
    respond_to do |format|
      format.html { redirect_to(question_path(@question)) }
      format.json {head :ok}
      format.js { render :json => {:message => flash[:notice], :success => true}.to_json }
    end
  end

  def new
    @open_request = OpenRequest.new
    respond_to do |format|
      format.html
    end
  end

  def edit
    @open_request = @question.open_requests.find(params[:id])
    respond_to do |format|
      format.html
      format.js do
        render :json => {:html => render_to_string(:partial => "open_requests/form",
                                                   :locals => {:open_request => @open_request,
                                                               :question => @question,
                                                               :form_id => "question_open_form" })}.to_json
      end
    end
  end

  protected
  def find_question
    @question = current_group.questions.find_by_slug_or_id(params[:question_id])
  end

  def check_permissions
    @open_request = @question.open_requests.find(params[:id])
    if (@open_request && @open_request.user_id != current_user.id) ||
       !@question.can_be_requested_to_open_by?(current_user)
      flash[:error] = t("global.permission_denied")
      respond_to do |format|
        format.html {redirect_to question_path(@question)}
        format.js {render :json => {:success => false, :message => flash[:error]}}
      end
      return
    end
  end
end
