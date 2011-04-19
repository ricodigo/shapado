class FlagsController < ApplicationController
  before_filter :login_required
  before_filter :moderator_required, :only => [:index]
  before_filter :find_resource

  def index
    @flags = @resource.flags
  end

  def create
    @flag = Flag.new(:reason => params[:flag][:reason])

    flagged = false

    if @resource.user != current_user
      @resource.flags << @flag
      @flag.user = current_user
      if @flag.valid?
        @resource.save
        flagged = true
        @resource.flagged!
        flash[:notice] = t(:flash_notice, :scope => "flags.create")

        Jobs::Activities.async.on_flag(current_user.id, current_group.id,
                                       @flag.reason).commit!
      else
        flash[:error] = @flag.errors.full_messages.join(", ")
      end
    else
      flash[:error] = t(:flash_error, :scope => "flags.create")
    end

    respond_to do |format|
      format.html{redirect_to resource_url}

      format.json do
        if flagged
          render(:json => {:status => :ok,
                           :message => flash[:notice]}.to_json)
        else
          render(:json => {:status => :error, :message => flash[:error] }.to_json)
        end
      end
    end
  end

  def update
    @flag = @resource.flags.find(params[:id])
    @flag.reason = params[:flag][:reason]

    respond_to do |format|
      if @flag.valid?
        @resource.save
        flash[:notice] = t(:flash_notice, :scope => "flags.update")
        format.html { redirect_to(resource_url) }
        format.json { render :json => @flag.to_json }
        format.js { render :json => {:message => flash[:notice], :success => true }.to_json }
      else
        flash[:error] = @flag.errors.full_messages.join(", ")
        format.html { redirect_to(question_path(@flag)) }
        format.json { render :json => @flag.errors, :status => :unprocessable_entity}
        format.js { render :json => {:message => flash[:error], :success => false }.to_json }
      end
    end
  end

  def new
    @flag = Flag.new(:reason => "spam")
    @source = resource_url
    respond_to do |format|
      format.html
      format.js do
        render :json => {:html => render_to_string(:partial => "flags/form",
                                                   :locals => {:flag => @flag,
                                                               :source => @source,
                                                               :flaggeable => @resource,
                                                               :form_id => "question_flag_form" })}.to_json
      end
    end
  end

  def edit
    @flag = @resource.flags.find(params[:id])
    @source = resource_url
    respond_to do |format|
      format.html
      format.js do
        render :json => {:html => render_to_string(:partial => "flags/form",
                                                   :locals => {:flag => @flag,
                                                               :source => @source,
                                                               :flaggeable => @resource,
                                                               :form_id => "question_flag_form" })}.to_json
      end
    end
  end

  def destroy
    @resource.flags.find(params[:id]).destroy

    @resource.decrement(:flags_count => 1)
    flash[:notice] = t(:flash_notice, :scope => "flag.destroy")
    respond_to do |format|
      format.html { redirect_to(resource_url) }
      format.json { head :ok }
      format.js { render :json => {:message => flash[:notice], :success => true}.to_json }
    end
  end

  protected
  def find_resource
    if params[:answer_id]
      @resource = current_group.answers.find(params[:answer_id])
    elsif params[:question_id]
      @resource = current_group.questions.find_by_slug_or_id(params[:question_id])
    end
  end

  def resource_url
    if @resource.is_a?(Answer)
      question_path(@resource.question)
    elsif @resource.is_a?(Question)
      question_path(@resource)
    else
      params[:return_to]
    end
  end
end
