class ActivitiesController < ApplicationController
  def index
    conds = {}
    if params[:context] == "by_me" && logged_in?
      conds[:user_id] = current_user.id
    end

    @activities = current_group.activities.where(conds).order(:created_at.desc).
                                           paginate(paginate_opts(params))

    respond_to do |format|
      format.html
      format.json { render :json => @activities }
    end
  end

end
