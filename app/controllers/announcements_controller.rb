class AnnouncementsController < ApplicationController
  before_filter :login_required
  before_filter :check_permissions
  layout "manage"

  tabs :default => :announcements

  # GET /announcements
  # GET /announcements.json
  def index
    @announcements = current_group.announcements.order_by("updated_at desc").
                                                 paginate(paginate_opts(params))

    @announcement = Announcement.new

    respond_to do |format|
      format.html # index.html.haml
      format.json  { render :json => @announcements }
    end
  end

  # POST /announcements
  # POST /announcements.json
  def create
    @announcement = Announcement.new
    @announcement.safe_update(%w[message only_anonymous], params[:announcement])

    @announcement.starts_at = build_datetime(params[:announcement], "starts_at")
    @announcement.ends_at = build_datetime(params[:announcement], "ends_at")

    @announcement.group = current_group

    respond_to do |format|
      if @announcement.save
        flash[:notice] = I18n.t("announcements.create.success")
        format.html { redirect_to announcements_url }
        format.json  { render :json => @announcement, :status => :created, :location => @announcement }
      else
        format.html { render :action => "index" }
        format.json  { render :json => @announcement.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /announcements/1
  # DELETE /announcements/1.json
  def destroy
    @announcement = current_group.announcements.find(params[:id])
    @announcement.destroy

    respond_to do |format|
      format.html { redirect_to(announcements_url) }
      format.json  { head :ok }
    end
  end

  def hide
    session[:announcement_hide_time] = Time.zone.now

    respond_to do |format|
      format.html { redirect_to root_path }
      format.js { render :json => {:status => "ok"} }
    end
  end

  protected
  def check_permissions
    if current_group.nil?
      redirect_to root_path
    elsif !current_user.owner_of?(current_group) && !current_user.admin?
      flash[:error] = t("global.permission_denied")
      redirect_to domain_url(:custom => current_group.domain)
    end
  end
end
