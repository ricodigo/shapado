class UsersController < ApplicationController
  before_filter :login_required, :only => [:edit, :update,
                                           :follow, :follow_tags,
                                           :unfollow_tags]
  tabs :default => :users

  subtabs :index => [[:reputation, "reputation"],
                     [:newest, %w(created_at desc)],
                     [:oldest, %w(created_at asc)],
                     [:name, %w(login asc)],
                     [:near, ""]]

  def index
    set_page_title(t("users.index.title"))

    order = current_order
    options =  {:per_page => params[:per_page]||24,
               :page => params[:page] || 1}
    conditions = {}
    conditions = {:login => /^#{Regexp.escape(params[:q])}/} if params[:q]

    if order == "reputation"
      order = %w(membership_list.#{current_group.id}.reputation desc)
    end

    @users = if order.blank?
               current_group.users(conditions.merge(:near => current_user.point)).paginate(options)
             else
               current_group.users(conditions).order_by(order).paginate(options)
             end
    respond_to do |format|
      format.html
      format.json {
        render :json => @users.to_json(:only => %w[name login membership_list bio website location language])
      }
      format.js {
        html = render_to_string(:partial => "user", :collection  => @users)
        pagination = render_to_string(:partial => "shared/pagination", :object => @users,
                                      :format => "html")
        render :json => {:html => html, :pagination => pagination }
      }
    end

  end

  # render new.rhtml
  def new
    @user = User.new
    @user.timezone = AppConfig.default_timezone
  end

  def create
    @user = User.new
    @user.safe_update(%w[login email name password_confirmation password preferred_languages website
                         language timezone identity_url bio hide_country], params[:user])
    if params[:user]["birthday(1i)"]
      @user.birthday = build_date(params[:user], "birthday")
    end
    success = @user && @user.save
    if success && @user.errors.empty?
      # Protects against session fixation attacks, causes request forgery
      # protection if visitor resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset session
      sweep_new_users(current_group)
      flash[:notice] = t("flash_notice", :scope => "users.create")
      sign_in_and_redirect(:user, @user) # !! now logged in
    else
      flash[:error]  = t("flash_error", :scope => "users.create")
      render :action => 'new'
    end
  end

  def show
    conds = {}
    conds[:se_id] = params[:se_id] if params[:se_id]
    @user = User.find_by_login_or_id(params[:id], conds)
    raise Goalie::NotFound unless @user

    set_page_title(t("users.show.title", :user => @user.login))

    @q_sort, order = active_subtab(:q_sort)
    @questions = @user.questions.paginate(:page=>params[:questions_page],
                                          :order => order,
                                          :per_page => 10,
                                          :group_id => current_group.id,
                                          :banned => false,
                                          :anonymous => false)

    @a_sort, order = active_subtab(:a_sort)
    @answers = @user.answers.paginate(:page=>params[:answers_page],
                                      :order => order,
                                      :group_id => current_group.id,
                                      :per_page => 10,
                                      :banned => false,
                                      :anonymous => false)

    @badges = @user.badges.paginate(:page => params[:badges_page],
                                    :group_id => current_group.id,
                                    :per_page => 25)

    @f_sort, order = active_subtab(:f_sort)

    @favorites = @user.favorites(:group_id => current_group.id).
      paginate(:page => params[:favorites_page],
               :per_page => 25,
               :order => order
               )

    add_feeds_url(url_for(:format => "atom"), t("feeds.user"))

    @user.viewed_on!(current_group) if @user != current_user && !is_bot?

    respond_to do |format|
      format.html
      format.atom
      format.json {
        render :json => @user.to_json(:only => %w[name login membership_list bio website location language])
      }
    end
  end

  def edit
    @user = current_user
    @user.timezone = AppConfig.default_timezone if @user.timezone.blank?
  end

  def update
    if params[:id] == 'login' && params[:user].nil? # HACK for facebook-connectable
      redirect_to root_path
      return
    end

    @user = current_user

    if params[:current_password] && @user.valid_password?(params[:current_password])
      @user.encrypted_password = ""
      @user.password = params[:user][:password]
      @user.password_confirmation = params[:user][:password_confirmation]
    end

    @user.safe_update(%w[login email name language timezone preferred_languages
                         notification_opts bio hide_country website avatar use_gravatar], params[:user])

    if params[:user]["birthday(1i)"]
      @user.birthday = build_date(params[:user], "birthday")
    end

    Jobs::Users.async.on_update_user(@user.id, current_group.id).commit!

    preferred_tags = params[:user][:preferred_tags]
    if @user.valid? && @user.save
      @user.add_preferred_tags(preferred_tags, current_group) if preferred_tags
      redirect_to root_path
    else
      render :action => "edit"
    end
  end

  # My feed, this returns:
  # - all the questions I asked
  # - all the questions I follow
  # - all the questions followed by people I follow
  #   (questions followed by people I find interesting must be interesting to me)
  # - all the questions tagged with one of the tag I follow
  def feed
    @user = params[:id] ? current_group.users.where(:login => params[:id]).first : current_user
    tags = @user.config_for(current_group).preferred_tags
    user_ids = @user.friend_list.following_ids
    user_ids << @user.id
    find_questions({ }, :any_of => [{:follower_ids.in => user_ids},
                                    {:tags.in => tags},
                                    {:user_id => user_ids}])
  end

  def by_me
    @user = params[:id] ? current_group.users.where(:login => params[:id]).first : current_user
    find_questions(:user_id => @user.id)
  end

  def preferred
    @user = params[:id] ? current_group.users.where(:login => params[:id]).first : current_user
    tags = @user.config_for(current_group).preferred_tags

    find_questions(:tags.in => tags)
  end

  def expertise
    @user = params[:id] ? current_group.users.where(:login => params[:id]).first : current_user
    tags = @user.stats(:expert_tags).expert_tags # TODO: optimize

    find_questions(:tags.in => tags)
  end

  def contributed
    @user = params[:id] ? current_group.users.where(:login => params[:id]).first : current_user

    find_questions(:contributor_ids => @user.id)
  end

  def connect
    authenticate_user!
    warden.authenticate!(:scope => :openid_identity, :recall => "show")
    current_openid_identity.user = current_user
    current_openid_identity.save!
    sign_out :openid_identity

    redirect_to settings_path
  end

  def follow_tags
    @user = current_user
    if tags = params[:tags]
      @user.add_preferred_tags(tags, current_group) if tags
    end
    flash[:notice] = t("users.update_followed_tags.followed.flash_notice",
                       :tag => params[:tags])
    respond_to do |format|
      format.html {redirect_to questions_path}
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
    end
  end

  def unfollow_tags
    @user = current_user
    if tags = params[:tags]
      @user.remove_preferred_tags(tags, current_group)
    end
    flash[:notice] = t("users.update_followed_tags.unfollowed.flash_notice",
                       :tag => params[:tags])
    respond_to do |format|
      format.html {redirect_to questions_path}
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
    end
  end

  def follow
    @user = User.find_by_login_or_id(params[:id])
    current_user.add_friend(@user)

    flash[:notice] = t("flash_notice", :scope => "users.follow", :user => @user.login)

    Jobs::Activities.async.on_follow(current_user.id, @user.id, current_group.id).commit!
    Jobs::Mailer.async.on_follow(current_user.id, @user.id, current_group.id).commit!

    respond_to do |format|
      format.html do
        redirect_to user_path(@user)
      end
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
    end
  end

  def unfollow
    @user = User.find_by_login_or_id(params[:id])
    current_user.remove_friend(@user)

    flash[:notice] = t("flash_notice", :scope => "users.unfollow", :user => @user.login)

    Jobs::Activities.async.on_unfollow(current_user.id, @user.id, current_group.id).commit!

    respond_to do |format|
      format.html do
        redirect_to user_path(@user)
      end
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
    end
  end

  def autocomplete_for_user_login
    @users = User.only(:login).
                  where(:login =>  /^#{Regexp.escape(params[:term].to_s.downcase)}.*/).
                  limit(20).
                  order_by(:login.desc).
                  all

    respond_to do |format|
      format.json {render :json=>@users}
    end
  end

  def destroy
    if false && current_user.delete # FIXME We need a better way to delete users
      flash[:notice] = t("destroyed", :scope => "devise.registrations")
    else
      flash[:notice] = t("destroy_failed", :scope => "devise.registrations")
    end
    return redirect_to(:root)
  end

  def suggestions
  end
  protected
  def active_subtab(param)
    key = params.fetch(param, "votes")
    order = "votes_average desc, created_at desc"
    case key
      when "votes"
        order = "votes_average desc, created_at desc"
      when "views"
        order = "views desc, created_at desc"
      when "newest"
        order = "created_at desc"
      when "oldest"
        order = "created_at asc"
    end
    [key, order]
  end
end


