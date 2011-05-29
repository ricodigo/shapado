class CommentsController < ApplicationController
  before_filter :login_required, :except => [:index]
  before_filter :find_scope
  before_filter :check_permissions, :except => [:create, :index]

  def index
    @comments = @answer ? @answer.comments : @question.comments

    respond_to do |format|
      format.json { render :json => @comments }
    end
  end

  def create
    @comment = Comment.new
    @comment.body = params[:comment][:body]
    @comment.user = current_user

    current_scope << @comment

    if @comment.valid? && saved = (@comment.save && scope.save)
      current_user.on_activity(:comment_question, current_group)
      current_user.increment({"membership_list.#{current_group.id}.comments_count" => 1})
      link = question_url(@question)

      Jobs::Activities.async.on_comment(scope.id, scope.class.to_s, @comment.id, link).commit!
      Jobs::Mailer.async.on_new_comment(scope.id, scope.class.to_s, @comment.id).commit!

      if question_id = @comment.question_id
        Question.update_last_target(question_id, @comment)
      end

      flash[:notice] = t("comments.create.flash_notice")
    else
      flash[:error] = @comment.errors.full_messages.join(", ")
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
    @comment = current_scope.find(params[:id])
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
      @comment = current_scope.find(params[:id])
      @comment.body = params[:comment][:body]
      if @comment.valid? && scope.save
        if question_id = @comment.question_id
          Question.update_last_target(question_id, @comment)
        end

        flash[:notice] = t(:flash_notice, :scope => "comments.update")
        format.html { redirect_to(params[:source]) }
        format.json { render :json => @comment.to_json, :status => :ok}
        format.js { render :json => { :message => flash[:notice],
                                      :success => true,
                                      :body => @comment.body} }
      else
        flash[:error] = @comment.errors.full_messages.join(", ")
        format.html { render :action => "edit" }
        format.json { render :json => @comment.errors, :status => :unprocessable_entity }
        format.js { render :json => { :success => false, :message => flash[:error]}.to_json }
      end
    end
  end

  def destroy
    @scope = scope
    @scope.comments.delete_if { |f| f._id == params[:id] }
    current_user.decrement({"membership_list.#{group.id}.comments_count" => 1})
    @scope.save!

    respond_to do |format|
      format.html { redirect_to(params[:source]) }
      format.json { head :ok }
    end
  end

  protected
  def check_permissions
    @comment = current_scope.find(params[:id])
    valid = false
    if params[:action] == "destroy"
      valid = @comment.can_be_deleted_by?(current_user)
    else
      valid = current_user.can_modify?(@comment) || current_user.mod_of?(@comment.group)
    end

    if !valid
      respond_to do |format|
        format.html do
          flash[:error] = t("global.permission_denied")
          redirect_to params[:source] || questions_path
        end
        format.js { render :json => {:success => false, :message => t("global.permission_denied") } }
        format.json { render :json => {:message => t("global.permission_denied")}, :status => :unprocessable_entity }
      end
    end
  end

  def current_scope
    scope.comments
  end

  def find_scope
    @question = current_group.questions.by_slug(params[:question_id])
    @answer = @question.answers.find(params[:answer_id]) unless params[:answer_id].blank?
  end

  def scope
    unless @answer.nil?
      @answer
    else
      @question
    end
  end

  def full_scope
    unless @answer.nil?
      [@question, @answer]
    else
      [@question]
    end
  end
  helper_method :full_scope

end
