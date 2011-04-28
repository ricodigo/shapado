class InvitationsController < ApplicationController
  before_filter :login_required, :except => :accept

  def index
  end

  def create
    emails = params[:invitations][:emails].split(',')
    user_role = params[:invitations][:user_role]
    emails.each do |email|
      unless email.blank?
        invitation = current_user.invite(email, user_role,
                                       current_group)
        Jobs::Mailer.async.on_new_invitation(invitation.id).commit!
      end
    end
    flash[:notice] = t("flash_notice", :scope => "invitations.create")
    redirect_to :back
  end

  def accept
    @invitation = Invitation.find(params[:id])
    @group = @invitation.group
    if @invitation.group.is_email_only_signup? && @invitation.state?(:pending) &&
        !logged_in?
      redirect_to new_user_path(:invitation_id => params[:id])
    elsif @invitation.state?(:pending) && logged_in?
      @invitation.connect!
    end
    @invitation.send(params[:step]) if params[:step]
    if @invitation.state?(:follow_suggestions)
      redirect_to '/'
    end
  end

  def revoke
    invitation = Invitation.find(params[:id])
    current_user.revoke_invite(invitation)
    redirect_to :back
  end
end
