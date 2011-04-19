class InvitationsController < ApplicationController
  before_filter :login_required, :except => :accept

  def index
  end

  def create
    emails = params[:invitations][:emails].split(',')
    user_role = params[:invitations][:user_role]
    emails.each do |email|
      invitation = current_user.invite(email, user_role,
                                       current_group)
      Jobs::Mailer.async.on_new_invitation(invitation.id).commit!
    end
    flash[:notice] = t("flash_notice", :scope => "invitations.create")
    redirect_to :back
  end

  def accept
    @invitation = Invitation.find(params[:id])
    unless @invitation.nil? ||
        @invitation.accepted_by_other?(current_user)
      @group = @invitation.group
      @inviter = @invitation.user
      if @group.is_email_only_signup?
        redirect_to new_user_path(:invitations_id => params[:id])
      elsif logged_in? && !params[:step]
        current_user.accept_invitation(@invitation.id)
        if current_user.created_at < 1.day.ago && current_group.is_noemail_signup?
          # don't make user confirm his email/pass if it's an old user
          # or if group doesn't require email/pass
          redirect_to accept_invitation_path(:id => @invitation.id, :step => 3)
        else
          redirect_to accept_invitation_path(:id => @invitation.id, :step => 2)
        end
      end
    else
      redirect_to '/'
    end
  end

  def revoke
    invitation = Invitation.find(params[:id])
    current_user.revoke_invite(invitation)
    redirect_to :back
  end
end
