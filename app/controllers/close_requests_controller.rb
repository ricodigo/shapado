class CloseRequestsController < ApplicationController
  before_filter :login_required
  before_filter :moderator_required, :only => [:index]
  before_filter :find_question
  before_filter :check_permissions, :except => [:create, :new, :index]

  def index
    @close_requests = @question.close_requests
  end

  def new
    @close_request = CloseRequest.new(:reason => "dupe")
    respond_to do |format|
      format.html
      format.js do
        render :json => {:html => render_to_string(:partial => "close_requests/form",
                                                   :locals => {:question => @question,
                                                               :close_request => @close_request})}.to_json
      end
    end
  end

  def create
    @close_request = CloseRequest.new(:reason => params[:close_request][:reason],
                                      :comment => params[:close_request][:comment])
    @close_request.user = current_user

    @question.close_requests << @close_request
    if current_user.mod_of?(current_group)
      @question.closed = params[:close]||false
      if @question.closed
        @question.close_reason_id = @close_request.id
      else
        @question.close_reason_id = nil
      end
    end

    respond_to do |format|
      if @close_request.valid?
        @question.save #FIXME: use modifiers
        @question.increment(:close_requests_count => 1)
        if @question.closed
          flash[:notice] = "question closed successfully"
        else
          flash[:notice] = t(:flash_notice, :scope => "close_requests.create")
        end
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @close_request.to_json, :status => :created}
        format.js { render :json => {:message => flash[:notice], :success => true }.to_json }
      else
        flash[:error] = @close_request.errors.full_messages.join(", ")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @close_request.errors, :status => :unprocessable_entity}
        format.js { render :json => {:message => flash[:error], :success => false }.to_json }
      end
    end
  end

  def edit
    @close_request = @question.close_requests.find(params[:id])
    respond_to do |format|
      format.html
      format.js do
        render :json => {:html => render_to_string(:partial => "close_requests/form",
                                                   :locals => {:close_request => @close_request,
                                                               :question => @question,
                                                               :form_id => "question_close_form" })}.to_json
      end
    end
  end

  def update
    @close_request = @question.close_requests.find(params[:id])
    @close_request.reason = params[:close_request][:reason]

    close_question = params[:close]||false
    if current_user.mod_of?(current_group)
      @question.closed = close_question
      if @question.closed_changed?
        if @question.closed
          @question.close_reason_id = @close_request.id
        else
          @question.close_reason_id = nil
        end
      end
    end

    respond_to do |format|
      if @close_request.valid?
        @question.save
        flash[:notice] = t(:flash_notice, :scope => "close_requests.update")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @close_request.to_json }
        format.js { render :json => {:message => flash[:notice], :success => true }.to_json }
      else
        flash[:error] = @close_request.errors.full_messages.join(", ")
        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @close_request.errors, :status => :unprocessable_entity}
        format.js { render :json => {:message => flash[:error], :success => false }.to_json }
      end
    end
  end

  def destroy
    @close_request = @question.close_requests.find(params[:id])
    if @question.closed && @question.close_reason_id == @close_request.id
      @question.closed = false
    end

    @close_request.destroy
    @question.decrement(:close_requests_count => 1)
    @question.save
    flash[:notice] = t(:flash_notice, :scope => "close_requests.destroy")
    respond_to do |format|
      format.html { redirect_to(question_path(@question)) }
      format.json {head :ok}
      format.js { render :json => {:message => flash[:notice], :success => true}.to_json }
    end
  end

  protected
  def find_question
    @question = current_group.questions.find_by_slug_or_id(params[:question_id])
  end

  def check_permissions
    @close_request = @question.close_requests.find(params[:id])
    if (@close_request && @close_request.user_id != current_user.id) ||
       (@question.closed && !current_user.mod_of?(current_group)) ||
       !@question.can_be_requested_to_close_by?(current_user)
      flash[:error] = t("global.permission_denied")
      respond_to do |format|
        format.html {redirect_to question_path(@question)}
        format.js {render :json => {:success => false, :message => flash[:error]}}
      end
      return
    end
  end
end
