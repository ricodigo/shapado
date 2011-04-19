
class MembersController < ApplicationController
  layout "manage"
  before_filter :login_required, :except => [:index, :show]
  before_filter :check_permissions, :only => [:create, :update, :edit, :destroy]
  tabs :default => :members

  def index
    @group = current_group
    @members = @group.users.order_by([%W[membership_list.#{@group.id}.role asc], %W[membership_list.#{@group.id}.reputation desc]]).
                            paginate(paginate_opts(params))
    @member = User.new
    @membership = Membership.new
  end

  def create
    @member = User.where(:login => params[:user_id]).first
    unless @member.nil?
      ok = @group.add_member(@member, params[:role])
      if ok
        flash[:notice] = "#{@member.login} was successfully added as #{params[:role]}"
        return redirect_to(members_path)
      end
    else
      flash[:error] = "Sorry, the user **#{params[:user_id]}** does not exists" # TODO: i18n
      @member = User.new(:login => params[:user_id])
    end

    @members = @group.users.paginate(paginate_opts(params))
    render :index
  end

  def update
    @member = @group.users(:_id => params[:id]).first
    if @member.id != current_user.id || current_user.admin?
      @member.config_for(@group).role = params[:role]
      @member.save
    else
      flash[:error] = "Sorry, you cannot be change the **#{@member.login}'s** membership"
    end
    redirect_to members_path
  end

  def destroy
    @member = @group.users(:_id => params[:id]).first
    if (@member.user_id != current_user.id) || current_user.admin?
      @member.destroy
    else
      flash[:error] = "Sorry, you cannot destroy the **#{@member.user.login}'s** membership"
    end
    redirect_to members_path
  end

  def check_permissions
    @group = current_group

    if !current_user.owner_of?(@group)
      flash[:notice] = t("global.permission_denied")
      redirect_to domain_url(:custom => current_group.domain)
    end
  end
end
