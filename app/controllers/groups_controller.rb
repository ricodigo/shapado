class GroupsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :check_permissions, :only => [:edit, :update, :close,
                                              :connect_group_to_twitter,
                                              :disconnect_twitter_group]
  before_filter :admin_required , :only => [:accept, :destroy]
  subtabs :index => [ [:most_active, "activity_rate desc"], [:newest, "created_at desc"],
                      [:oldest, "created_at asc"], [:name, "name asc"]]
  # GET /groups
  # GET /groups.json
  def index
    @state = "active"
    case params.fetch(:tab, "active")
      when "pendings"
        @state = "pending"
    end

    conds = {:state => @state, :private => false}

    if params[:q].blank?
      @groups = Group.where(conds).order_by(current_order).
                                   paginate(paginate_opts(params))
    else
      @groups = Group.filter(params[:q], options).order_by(current_order).
                                                  paginate(paginate_opts(params))
    end

    respond_to do |format|
      format.html # index.html.haml
      format.json  { render :json => @groups }
      format.js do
        html = render_to_string(:partial => "group", :collection  => @groups)
        pagination = render_to_string(:partial => "shared/pagination", :object => @groups,
                                      :format => "html")
        render :json => {:html => html, :pagination => pagination }
      end
    end
  end

  # GET /groups/1
  # GET /groups/1.json
  def show
    @active_subtab = "about"

    if params[:id]
      @group = Group.find_by_slug_or_id(params[:id])
    else
      @group = current_group
    end
    raise PageNotFound if @group.nil?

    respond_to do |format|
      format.html # show.html.erb
      format.json  { render :json => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.json
  def new
    @group = Group.new

    respond_to do |format|
      format.html # new.html.erb
      format.json  { render :json => @group }
    end
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = Group.new
    @group.safe_update(%w[name legend description default_tags subdomain logo forum enable_latex
                          custom_favicon language languages theme signup_type custom_css wysiwyg_editor], params[:group])

    @group.safe_update(%w[isolate domain private], params[:group]) if current_user.admin?

    @group.owner = current_user
    @group.state = "active"

    @group.reset_widgets!

    respond_to do |format|
      if @group.save
        Jobs::Images.async.generate_group_thumbnails(@group.id)
        @group.add_member(current_user, "owner")
        flash[:notice] = I18n.t("groups.create.flash_notice")
        format.html { redirect_to(domain_url(:custom => @group.domain, :controller => "admin/manage", :action => "properties")) }
        format.json  { render :json => @group.to_json, :status => :created, :location => @group }
      else
        format.html { render :action => "new" }
        format.json { render :json => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.json
  def update
    @group.safe_update(%w[name legend description default_tags subdomain logo logo_info forum enable_latex
                          custom_favicon language languages theme reputation_rewards reputation_constrains
                          has_adult_content registered_only signup_type custom_css wysiwyg_editor fb_button share notification_opts], params[:group])

    @group.safe_update(%w[isolate domain private has_custom_analytics has_custom_html has_custom_js], params[:group]) #if current_user.admin?
    @group.safe_update(%w[analytics_id analytics_vendor], params[:group]) if @group.has_custom_analytics
    @group.custom_html.update_attributes(params[:group][:custom_html] || {}) if @group.has_custom_html

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Group was successfully updated.' # TODO: i18n
        format.html { redirect_to(params[:source] ? params[:source] : group_path(@group)) }
        format.json  { head :ok }
      else
        format.html { render :action => "edit" }
        format.json  { render :json => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.json
  def destroy
    @group = Group.find_by_slug_or_id(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.json  { head :ok }
    end
  end

  def accept
    @group = Group.find_by_slug_or_id(params[:id])
    @group.has_custom_ads = true if params["has_custom_ads"] == "true"
    @group.state = "active"
    @group.save
    redirect_to group_path(@group)
  end

  def close
    @group.state = "closed"
    @group.save
    redirect_to group_path(@group)
  end

  def autocomplete_for_group_slug
    Group.only(:slug).where(:slug =>  /.*#{Regexp.escape(params[:term].downcase.to_s)}.*/,
                            :state => "active").
                      limit(20).
                      order_by(:slug.desc).
                      all

    respond_to do |format|
      format.json {render :json=>@groups}
    end
  end

  def allow_custom_ads
    if current_user.admin?
      @group = Group.find_by_slug_or_id(params[:id])
      @group.has_custom_ads = true
      @group.save
    end
    redirect_to groups_path
  end

  def disallow_custom_ads
    if current_user.admin?
      @group = Group.find_by_slug_or_id(params[:id])
      @group.has_custom_ads = false
      @group.save
    end
    redirect_to groups_path
  end

  def group_twitter_request_token
    config = Multiauth.providers["Twitter"]
    if !params[:oauth_verifier] && config
      client = TwitterOAuth::Client.new(:consumer_key => config["id"],
                                        :consumer_secret => config["token"])
      request_token = client.request_token(:oauth_callback => group_twitter_request_token_url)

      session[:twitter_token] = request_token.token
      session[:twitter_secret] = request_token.secret
      redirect_to request_token.authorize_url
     else
      connect_group_to_twitter
    end
  end

  #FIXME is this an action?
  def connect_group_to_twitter
    token = session[:twitter_token]
    secret = session[:twitter_secret]
    config = Multiauth.providers["Twitter"]
    client = TwitterOAuth::Client.new(:consumer_key =>  config["id"],
                                      :consumer_secret => config["token"] )
    @oauth_verifier = params[:oauth_verifier]
    access_token = client.authorize(token,
                                    secret,
                                    :oauth_verifier => @oauth_verifier)
    session[:twitter_secret] = nil
    session[:twitter_token] = nil
    if (client.authorized?)
      current_group.update_twitter_account_with_oauth_token(access_token.token,
                                                            access_token.secret,
                                                            access_token.params[:screen_name])
      flash[:notice] = t("groups.connect_group_to_twitter.success_twitter_connection")
      redirect_to manage_social_path
    else
      flash[:notice] = t("groups.connect_group_to_twitter.failed_twitter_connection")
      redirect_to manage_social_path
    end
  end

  def disconnect_twitter_group
    current_group.reset_twitter_account
    redirect_to manage_social_path
  end

  protected
  def check_permissions
    @group = Group.find_by_slug_or_id(params[:id]) || current_group

    if @group.nil?
      redirect_to groups_path
    elsif !current_user.owner_of?(@group)
      flash[:error] = t("global.permission_denied")
      redirect_to group_path(@group)
    end
  end
end
