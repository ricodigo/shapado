class CommentsController < ApplicationController
  before_filter :login_required
  before_filter :check_permissions, :except => [:create]

  def create
    @comment = Comment.new
    @comment.body = params[:body]
    @comment.commentable_type = params[:commentable_type]
    @comment.commentable_id = params[:commentable_id]
    @comment.user = current_user
    @comment.group = current_group

    if saved = @comment.save
      current_user.on_activity(:comment_question, current_group)
      Magent.push("actors.judge", :on_comment, @comment.id)
      flash[:notice] = t("comments.create.flash_notice")
    else
      flash[:error] = @comment.errors.full_messages.join(", ")
    end

    # TODO: use magent to do it
    if (question = @comment.find_question) && (recipient = @comment.find_recipient)
      email = recipient.email
      if !email.blank? && recipient.notification_opts["new_answer"] == "1"
        Notifier.deliver_new_comment(current_group, @comment, recipient, question)
      end
    end

    respond_to do |format|
      if saved
        format.html {redirect_to params[:source]}
        format.json {render :json => @comment.to_json, :status => :created}
        format.js do
          render(:json => {:success => true, :message => flash[:notice],
            :html => render_to_string(:partial => "comments/comment",
                                      :object => @comment,
                                      :locals => {:source => params[:source], :mini => true})}.to_json)
        end
      else
        format.html {redirect_to params[:source]}
        format.json {render :json => @comment.errors.to_json, :status => :unprocessable_entity }
        format.js {render :json => {:success => false, :message => flash[:error] }.to_json }
      end
    end
  end


  def edit
    @comment = Comment.find(params[:id])
    respond_to do |format|
      format.html
      format.js do
        render :json => {:status => :ok,
         :html => render_to_string(:partial => "comments/edit_form",
                                   :locals => {:source => params[:source],
                                               :commentable => @comment.commentable})
        }
      end
    end
  end

  def update
    respond_to do |format|
      @comment = Comment.find(params[:id])
      @comment.body = params[:body]
      if @comment.valid? && @comment.save
        flash[:notice] = t(:flash_notice, :scope => "comments.update")
        format.html { redirect_to(params[:source]) }
        format.json { render :json => @comment.to_json, :status => :ok}
        format.js { render :json => { :message => flash[:notice], :success => true } }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @comment.errors, :status => :unprocessable_entity }
        format.js { render :json => { :success => false } }
      end
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy

    respond_to do |format|
      format.html { redirect_to(params[:source]) }
      format.json { head :ok }
    end
  end

  protected
  def check_permissions
    @comment = Comment.find!(params[:id])
    if !(current_user.owner_of?(current_group) || current_user.can_modify?(@comment))
      format.html do
        flash[:error] = t("global.permission_denied")
        redirect_to params[:source]
      end
      format.json { render :json => {:message => t("global.permission_denied")}, :status => :unprocessable_entity }
    end
  end
end
