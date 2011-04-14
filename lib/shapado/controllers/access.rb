module Shapado
  module Controllers
    module Access
      def self.included(base)
        base.class_eval do
          helper_method :logged_in?
        end
      end

      def logged_in?
        user_signed_in?
      end

      def check_group_access
        if ((!current_group.registered_only || is_bot?) && !current_group.private) || devise_controller? || (params[:controller] == "users" && action_name == "new" )
          return
        end

        if logged_in?
          if !current_user.user_of?(@current_group)
            if cookie = cookie[:accept_invitation]
              current_user.accept_invitation(cookie)
            end
            raise Goalie::Forbidden
          end
        else
          respond_to do |format|
            format.json { render :json => {:message => "Permission denied" }}
            format.html { redirect_to new_user_session_path }
          end
        end
      end

      def admin_required
        unless current_user.admin?
          raise Goalie::Forbidden
        end
      end

      def moderator_required
        unless current_user.mod_of?(current_group)
          raise Goalie::Forbidden
        end
      end

      def owner_required
        unless current_user.owner_of?(current_group)
          raise Goalie::Forbidden
        end
      end

      def login_required
        respond_to do |format|
          format.js do
            if warden.authenticate(:scope => :user).nil?
              return render(:json => {:message => t("global.please_login"),
                                                :success => false,
                                                :status => :unauthenticate}.to_json)
            end
          end
          format.any { warden.authenticate!(:scope => :user) }
        end
      end

      def after_sign_in_path_for(resource)
        if current_user.admin?
          Jobs::Activities.async.on_admin_connect(request.remote_ip, current_user.id).commit!
        end
        if current_user.facebook_login? && current_user.facebook_friends.empty?
          Jobs::Users.async.get_facebook_friends(current_user.id).commit!
        end
        if current_user.twitter_login? && current_user.twitter_friends.empty?
          Jobs::Users.async.get_twitter_friends(current_user.id).commit!
        end
        if current_user.identica_login? && current_user.identica_friends.empty?
          Jobs::Users.async.get_identica_friends(current_user.id).commit!
        end
        if current_user.linked_in_login? && current_user.linked_in_friends.empty?
          Jobs::Users.async.get_linked_in_friends(current_user.id).commit!
        end
        if current_user.linked_in_login? || current_user.twitter_login? || current_user.identica_login? || current_user.linked_in_login?
          '/close_popup.html'
        else
          response.redirect root_path
        end
        
        #return
        #if return_to = session.delete("return_to")
        #  return_to
        #else
        #  super
        #end
      end
    end
  end
end
