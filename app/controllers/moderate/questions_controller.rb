class Moderate::QuestionsController < ApplicationController
  before_filter :login_required
  before_filter :moderator_required

  tabs :default => :questions
  subtabs :index => [[:retag, "created_at desc"]],
          :flagged => [[:flagged, "created_at desc"]]


  def index
    @active_subtab = "retagg"
    options = {:banned => false}

    @questions = current_group.questions.where(options.merge(:tags => {:$size => 0})).
                                         paginate(paginate_opts(params))
  end

  def flagged
    options = {:banned => false}

    if params[:filter] == "banned"
       options[:banned] = true
    else
      options[:flags_count] = {:$gt => 0}
    end

    @questions = current_group.questions. where(options).
                            order_by("flags_count desc").
                            paginate(paginate_opts(params))
  end

  def to_close
    options = { :closed => false}

    @questions = current_group.questions.
                            where(options.merge(:close_requests_count.gt => 0)).
                            order_by("close_requests_count desc").
                            paginate(paginate_opts(params))
  end

  def to_open
    options = {:closed => true}

    @questions = current_group.questions.
                        where(options.merge(:open_requests_count.gt => 0)).
                        order_by("open_requests_count desc").
                        paginate(paginate_opts(params))
  end

  def manage
    case params[:commit]
    when "ban"
      Question.ban(params[:question_ids] || [], {:group_id => current_group.id})
    when "unban"
      Question.unban(params[:question_ids] || [], {:group_id => current_group.id})
    when "delete"
      Question.delete_all({:_id.in =>  params[:question_ids], :group_id => current_group.id})
    end

    respond_to do |format|
      format.html{redirect_to :action => "flagged"}
    end
  end

  protected
  def current_scope
  end
end
