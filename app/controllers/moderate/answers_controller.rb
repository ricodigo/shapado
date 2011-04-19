class Moderate::AnswersController < ApplicationController
  before_filter :login_required, :except => [:show, :create]
  before_filter :moderator_required

  tabs :default => :questions
  subtabs :index => [[:retag, "created_at desc"]],
          :flagged => [[:flagged, "created_at desc"]]

  def index
    options = {:group_id => current_group.id}
    options[:banned] = false
    if params[:filter] == "banned"
      options[:banned] = true
    else
      options[:flags_count] = {:$gt => 0}
    end

    @answers = current_group.answers.
                                  where(options).
                                  order_by("flags_count desc").
                                  paginate(paginate_opts(params))
  end


  def manage
    case params[:commit]
    when "ban"
      Answer.ban(params[:answer_ids] || [], {:group_id => current_group.id})
    when "unban"
      Answer.unban(params[:answer_ids] || [], {:group_id => current_group.id})
    when "delete"
      Answer.delete_all({:_id.in =>  params[:answer_ids], :group_id => current_group.id})
    end

    respond_to do |format|
      format.html{redirect_to :action => "flagged"}
    end
  end

  protected
end
