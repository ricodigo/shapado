class QuestionsController < ApplicationController
  before_filter :login_required, :except => [:new, :create, :index, :show, :tags, :unanswered, :related_questions, :tags_for_autocomplete, :retag, :retag_to]
  before_filter :admin_required, :only => [:move, :move_to]
  before_filter :moderator_required, :only => [:close]
  before_filter :check_permissions, :only => [:solve, :unsolve, :destroy]
  before_filter :check_update_permissions, :only => [:edit, :update, :revert]
  before_filter :check_favorite_permissions, :only => [:favorite, :unfavorite] #TODO remove this
  before_filter :set_active_tag
  before_filter :check_age, :only => [:show]
  before_filter :check_retag_permissions, :only => [:retag, :retag_to]

  tabs :default => :questions, :tags => :tags,
       :unanswered => :unanswered, :new => :ask_question

  subtabs :index => [[:newest, "created_at desc"], [:hot, "hotness desc, views_count desc"], [:votes, "votes_average desc"], [:activity, "activity_at desc"], [:expert, "created_at desc"]],
          :unanswered => [[:newest, "created_at desc"], [:votes, "votes_average desc"], [:mytags, "created_at desc"]],
          :show => [[:votes, "votes_average desc"], [:oldest, "created_at asc"], [:newest, "created_at desc"]]
  helper :votes

  # GET /questions
  # GET /questions.xml
  def index
    if params[:language] || request.query_string =~ /tags=/
      params.delete(:language)
      head :moved_permanently, :location => url_for(params)
      return
    end

    set_page_title(t("questions.index.title"))
    conditions = scoped_conditions(:banned => false)

    if params[:sort] == "hot"
      conditions[:activity_at] = {"$gt" => 5.days.ago}
    end

    @questions = Question.paginate({:per_page => 25, :page => params[:page] || 1,
                       :order => current_order,
                       :fields => {:_keywords => 0, :watchers => 0, :flags => 0,
                                   :close_requests => 0, :open_requests => 0,
                                   :versions => 0}}.merge(conditions))

    @langs_conds = scoped_conditions[:language][:$in]

    if logged_in?
      feed_params = { :feed_token => current_user.feed_token }
    else
      feed_params = {  :lang => I18n.locale,
                          :mylangs => current_languages }
    end
    add_feeds_url(url_for({:format => "atom"}.merge(feed_params)), t("feeds.questions"))
    if params[:tags]
      add_feeds_url(url_for({:format => "atom", :tags => params[:tags]}.merge(feed_params)),
                    "#{t("feeds.tag")} #{params[:tags].inspect}")
    end
    @tag_cloud = Question.tag_cloud(scoped_conditions, 25)

    respond_to do |format|
      format.html # index.html.erb
      format.json  { render :json => @questions.to_json(:except => %w[_keywords watchers slugs]) }
      format.atom
    end
  end


  def history
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    respond_to do |format|
      format.html
      format.json { render :json => @question.versions.to_json }
    end
  end

  def diff
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    @prev = params[:prev]
    @curr = params[:curr]
    if @prev.blank? || @curr.blank? || @prev == @curr
      flash[:error] = "please, select two versions"
      render :history
    else
      if @prev
        @prev = (@prev == "current" ? :current : @prev.to_i)
      end

      if @curr
        @curr = (@curr == "current" ? :current : @curr.to_i)
      end
    end
  end

  def revert
    @question.load_version(params[:version].to_i)

    respond_to do |format|
      format.html
    end
  end

  def related_questions
    if params[:id]
      @question = current_group.questions.find(params[:id])
    elsif params[:question]
      @question = Question.new(params[:question])
      @question.group_id = current_group.id
    end

    @question.tags += @question.title.downcase.split(",").join(" ").split(" ") if @question.title

    @questions = Question.related_questions(@question, :page => params[:page],
                                                       :per_page => params[:per_page],
                                                       :order => "answers_count desc",
                                                       :fields => {:_keywords => 0, :watchers => 0, :flags => 0,
                                                                  :close_requests => 0, :open_requests => 0,
                                                                  :versions => 0})

    respond_to do |format|
      format.js do
        render :json => {:html => render_to_string(:partial => "questions/question",
                                                   :collection  => @questions,
                                                   :locals => {:mini => true, :lite => true})}.to_json
      end
    end
  end

  def unanswered
    if params[:language] || request.query_string =~ /tags=/
      params.delete(:language)
      head :moved_permanently, :location => url_for(params)
      return
    end

    set_page_title(t("questions.unanswered.title"))
    conditions = scoped_conditions({:answered_with_id => nil, :banned => false, :closed => false})

    if logged_in?
      if @active_subtab.to_s == "expert"
        @current_tags = current_user.stats(:expert_tags).expert_tags
      elsif @active_subtab.to_s == "mytags"
        @current_tags = current_user.preferred_tags_on(current_group)
      end
    end

    @tag_cloud = Question.tag_cloud(conditions, 25)

    @questions = Question.paginate({:order => current_order,
                                    :per_page => 25,
                                    :page => params[:page] || 1,
                                    :fields => {:_keywords => 0, :watchers => 0, :flags => 0,
                                                :close_requests => 0, :open_requests => 0,
                                                :versions => 0}
                                   }.merge(conditions))

    respond_to do |format|
      format.html # unanswered.html.erb
      format.json  { render :json => @questions.to_json(:except => %w[_keywords slug watchers]) }
    end
  end

  def tags
    conditions = scoped_conditions({:answered_with_id => nil, :banned => false})
    if params[:q].blank?
      @tag_cloud = Question.tag_cloud(conditions)
    else
      @tag_cloud = Question.find_tags(/^#{Regexp.escape(params[:q])}/, conditions)
    end
    respond_to do |format|
      format.html do
        set_page_title(t("layouts.application.tags"))
      end
      format.js do
        html = render_to_string(:partial => "tag_table", :object => @tag_cloud)
        render :json => {:html => html}
      end
      format.json  { render :json => @tag_cloud.to_json }
    end
  end

  def tags_for_autocomplete
    respond_to do |format|
      format.js do
        result = []
        if q = params[:tag]
          result = Question.find_tags(/^#{Regexp.escape(q.downcase)}/i,
                                      :group_id => current_group.id,
                                      :banned => false)
        end

        results = result.map do |t|
          {:caption => "#{t["name"]} (#{t["count"].to_i})", :value => t["name"]}
        end
        # if no results, show default tags
        if results.empty?
          results = current_group.default_tags.map  {|tag|{:value=> tag, :caption => tag}}
        end
        render :json => results
      end
    end
  end

  # GET /questions/1
  # GET /questions/1.xml
  def show
    if params[:language]
      params.delete(:language)
      head :moved_permanently, :location => url_for(params)
      return
    end

    @tag_cloud = Question.tag_cloud(:_id => @question.id, :banned => false)
    options = {:per_page => 25, :page => params[:page] || 1,
               :order => current_order, :banned => false}
    options[:_id] = {:$ne => @question.answer_id} if @question.answer_id
    options[:fields] = {:_keywords => 0}
    @answers = @question.answers.paginate(options)

    @answer = Answer.new(params[:answer])

    if @question.user != current_user && !is_bot?
      @question.viewed!(request.remote_ip)

      if (@question.views_count % 10) == 0
        sweep_question(@question)
      end
    end

    set_page_title(@question.title)
    add_feeds_url(url_for(:format => "atom"), t("feeds.question"))

    respond_to do |format|
      format.html { Magent.push("actors.judge", :on_view_question, @question.id) }
      format.json  { render :json => @question.to_json(:except => %w[_keywords slug watchers]) }
      format.atom
    end
  end

  # GET /questions/new
  # GET /questions/new.xml
  def new
    @question = Question.new(params[:question])
    respond_to do |format|
      format.html # new.html.erb
      format.json  { render :json => @question.to_json }
    end
  end

  # GET /questions/1/edit
  def edit
  end

  # POST /questions
  # POST /questions.xml
  def create
    @question = Question.new
    @question.safe_update(%w[title body language tags wiki], params[:question])
    @question.anonymous = Boolean.to_mongo(params[:question][:anonymous])

    @question.group = current_group
    @question.user = current_user

    if !logged_in?
      if recaptcha_valid? && params[:user]
        @user = User.first(:email => params[:user][:email])
        if @user.present?
          if !@user.anonymous
            flash[:notice] = "The user is already registered, please log in"
            return create_draft!
          else
            @question.user = @user
          end
        else
          @user = User.new(:anonymous => true, :login => "Anonymous")
          @user.safe_update(%w[name email website], params[:user])
          @user.login = @user.name if @user.name.present?
          @user.save!
          @question.user = @user
        end
      elsif !AppConfig.recaptcha["activate"]
        return create_draft!
      end
    end

    respond_to do |format|
      if (logged_in? ||  (@question.user.valid? && recaptcha_valid?)) && @question.save
        sweep_question_views

        current_group.tag_list.add_tags(*@question.tags)
        unless @question.anonymous
          @question.user.stats.add_question_tags(*@question.tags)
          @question.user.on_activity(:ask_question, current_group)
          Magent.push("actors.judge", :on_ask_question, @question.id)

          # TODO: move to magent
          users = User.find_experts(@question.tags, [@question.language],
                                                    :except => [@question.user.id],
                                                    :group_id => current_group.id)
          followers = @question.user.followers(:group_id => current_group.id, :languages => [@question.language])

          (users - followers).each do |u|
            if !u.email.blank?
              Notifier.deliver_give_advice(u, current_group, @question, false)
            end
          end

          followers.each do |u|
            if !u.email.blank?
              Notifier.deliver_give_advice(u, current_group, @question, true)
            end
          end
        end

        current_group.on_activity(:ask_question)
        flash[:notice] = t(:flash_notice, :scope => "questions.create")

        format.html { redirect_to(question_path(@question)) }
        format.json { render :json => @question.to_json(:except => %w[_keywords watchers]), :status => :created}
      else
        @question.errors.add(:captcha, "is invalid") unless recaptcha_valid?
        format.html { render :action => "new" }
        format.json { render :json => @question.errors+@question.user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /questions/1
  # PUT /questions/1.xml
  def update
    respond_to do |format|
      @question.safe_update(%w[title body language tags wiki adult_content version_message], params[:question])
      @question.updated_by = current_user
      @question.last_target = @question

      @question.slugs << @question.slug
      @question.send(:generate_slug)

      if @question.valid? && @question.save
        sweep_question_views
        sweep_question(@question)

        flash[:notice] = t(:flash_notice, :scope => "questions.update")
        format.html { redirect_to(question_path(@question)) }
        format.json  { head :ok }
      else
        format.html { render :action => "edit" }
        format.json  { render :json => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /questions/1
  # DELETE /questions/1.xml
  def destroy
    if @question.user_id == current_user.id
      @question.user.update_reputation(:delete_question, current_group)
    end
    sweep_question(@question)
    sweep_question_views
    @question.destroy

    Magent.push("actors.judge", :on_destroy_question, current_user.id, @question.attributes)

    respond_to do |format|
      format.html { redirect_to(questions_url) }
      format.json  { head :ok }
    end
  end

  def solve
    @answer = @question.answers.find(params[:answer_id])
    @question.answer = @answer
    @question.accepted = true
    @question.answered_with = @answer if @question.answered_with.nil?

    respond_to do |format|
      if @question.save
        sweep_question(@question)

        current_user.on_activity(:close_question, current_group)
        if current_user != @answer.user
          @answer.user.update_reputation(:answer_picked_as_solution, current_group)
        end

        Magent.push("actors.judge", :on_question_solved, @question.id, @answer.id)

        flash[:notice] = t(:flash_notice, :scope => "questions.solve")
        format.html { redirect_to question_path(@question) }
        format.json  { head :ok }
      else
        @tag_cloud = Question.tag_cloud(:_id => @question.id, :banned => false)
        options = {:per_page => 25, :page => params[:page] || 1,
                   :order => current_order, :banned => false}
        options[:_id] = {:$ne => @question.answer_id} if @question.answer_id
        @answers = @question.answers.paginate(options)
        @answer = Answer.new

        format.html { render :action => "show" }
        format.json  { render :json => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  def unsolve
    @answer_id = @question.answer.id
    @answer_owner = @question.answer.user

    @question.answer = nil
    @question.accepted = false
    @question.answered_with = nil if @question.answered_with == @question.answer

    respond_to do |format|
      if @question.save
        sweep_question(@question)

        flash[:notice] = t(:flash_notice, :scope => "questions.unsolve")
        current_user.on_activity(:reopen_question, current_group)
        if current_user != @answer_owner
          @answer_owner.update_reputation(:answer_unpicked_as_solution, current_group)
        end

        Magent.push("actors.judge", :on_question_unsolved, @question.id, @answer_id)

        format.html { redirect_to question_path(@question) }
        format.json  { head :ok }
      else
        @tag_cloud = Question.tag_cloud(:_id => @question.id, :banned => false)
        options = {:per_page => 25, :page => params[:page] || 1,
                   :order => current_order, :banned => false}
        options[:_id] = {:$ne => @question.answer_id} if @question.answer_id
        @answers = @question.answers.paginate(options)
        @answer = Answer.new

        format.html { render :action => "show" }
        format.json  { render :json => @question.errors, :status => :unprocessable_entity }
      end
    end
  end

  def close
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    @question.closed = true
    @question.closed_at = Time.zone.now
    @question.close_reason_id = params[:close_request_id]

    respond_to do |format|
      if @question.save
        sweep_question(@question)

        format.html { redirect_to question_path(@question) }
        format.json { head :ok }
      else
        flash[:error] = @question.errors.full_messages.join(", ")
        format.html { redirect_to question_path(@question) }
        format.json { render :json => @question.errors, :status => :unprocessable_entity  }
      end
    end
  end

  def open
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    @question.closed = false
    @question.close_reason_id = nil

    respond_to do |format|
      if @question.save
        sweep_question(@question)

        format.html { redirect_to question_path(@question) }
        format.json { head :ok }
      else
        flash[:error] = @question.errors.full_messages.join(", ")
        format.html { redirect_to question_path(@question) }
        format.json { render :json => @question.errors, :status => :unprocessable_entity  }
      end
    end
  end

  def favorite
    @favorite = Favorite.new
    @favorite.question = @question
    @favorite.user = current_user
    @favorite.group = @question.group

    @question.add_watcher(current_user)

    if (@question.user_id != current_user.id) && current_user.notification_opts.activities
      Notifier.deliver_favorited(current_user, @question.group, @question)
    end

    respond_to do |format|
      if @favorite.save
        @question.add_favorite!(@favorite, current_user)
        flash[:notice] = t("favorites.create.success")
        format.html { redirect_to(question_path(@question)) }
        format.json { head :ok }
        format.js {
          render(:json => {:success => true,
                   :message => flash[:notice], :increment => 1 }.to_json)
        }
      else
        flash[:error] = @favorite.errors.full_messages.join("**")
        format.html { redirect_to(question_path(@question)) }
        format.js {
          render(:json => {:success => false,
                   :message => flash[:error], :increment => 0 }.to_json)
        }
        format.json { render :json => @favorite.errors, :status => :unprocessable_entity }
      end
    end
  end

  def unfavorite
    @favorite = current_user.favorite(@question)
    if @favorite
      if current_user.can_modify?(@favorite)
        @question.remove_favorite!(@favorite, current_user)
        @favorite.destroy
        @question.remove_watcher(current_user)
      end
    end
    flash[:notice] = t("unfavorites.create.success")
    respond_to do |format|
      format.html { redirect_to(question_path(@question)) }
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice], :increment => -1 }.to_json)
      }
      format.json  { head :ok }
    end
  end

  def watch
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    @question.add_watcher(current_user)
    flash[:notice] = t("questions.watch.success")
    respond_to do |format|
      format.html {redirect_to question_path(@question)}
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
      format.json { head :ok }
    end
  end

  def unwatch
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    @question.remove_watcher(current_user)
    flash[:notice] = t("questions.unwatch.success")
    respond_to do |format|
      format.html {redirect_to question_path(@question)}
      format.js {
        render(:json => {:success => true,
                 :message => flash[:notice] }.to_json)
      }
      format.json { head :ok }
    end
  end

  def move
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    render
  end

  def move_to
    @group = Group.find_by_slug_or_id(params[:question][:group])
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    if @group
      @question.group = @group

      if @question.save
        sweep_question(@question)

        Answer.set({"question_id" => @question.id}, {"group_id" => @group.id})
      end
      flash[:notice] = t("questions.move_to.success", :group => @group.name)
      redirect_to question_path(@question)
    else
      flash[:error] = t("questions.move_to.group_dont_exists",
                        :group => params[:question][:group])
      render :move
    end
  end

  def retag_to
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    @question.tags = params[:question][:tags]
    @question.updated_by = current_user
    @question.last_target = @question

    if @question.save
      sweep_question(@question)

      if (Time.now - @question.created_at) < 8.days
        @question.on_activity(true)
      end

      Magent.push("actors.judge", :on_retag_question, @question.id, current_user.id)

      flash[:notice] = t("questions.retag_to.success", :group => @question.group.name)
      respond_to do |format|
        format.html {redirect_to question_path(@question)}
        format.js {
          render(:json => {:success => true,
                   :message => flash[:notice], :tags => @question.tags }.to_json)
        }
      end
    else
      flash[:error] = t("questions.retag_to.failure",
                        :group => params[:question][:group])

      respond_to do |format|
        format.html {render :retag}
        format.js {
          render(:json => {:success => false,
                   :message => flash[:error] }.to_json)
        }
      end
    end
  end


  def retag
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    respond_to do |format|
      format.html {render}
      format.js {
        render(:json => {:success => true, :html => render_to_string(:partial => "questions/retag_form",
                                                   :member  => @question)}.to_json)
      }
    end
  end

  protected
  def check_permissions
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    if @question.nil?
      redirect_to questions_path
    elsif !(current_user.can_modify?(@question) ||
           (params[:action] != 'destroy' && @question.can_be_deleted_by?(current_user)) ||
           current_user.owner_of?(@question.group)) # FIXME: refactor
      flash[:error] = t("global.permission_denied")
      redirect_to question_path(@question)
    end
  end

  def check_update_permissions
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    allow_update = true
    unless @question.nil?
      if !current_user.can_modify?(@question)
        if @question.wiki
          if !current_user.can_edit_wiki_post_on?(@question.group)
            allow_update = false
            reputation = @question.group.reputation_constrains["edit_wiki_post"]
            flash[:error] = I18n.t("users.messages.errors.reputation_needed",
                                        :min_reputation => reputation,
                                        :action => I18n.t("users.actions.edit_wiki_post"))
          end
        else
          if !current_user.can_edit_others_posts_on?(@question.group)
            allow_update = false
            reputation = @question.group.reputation_constrains["edit_others_posts"]
            flash[:error] = I18n.t("users.messages.errors.reputation_needed",
                                        :min_reputation => reputation,
                                        :action => I18n.t("users.actions.edit_others_posts"))
          end
        end
        return redirect_to question_path(@question) if !allow_update
      end
    else
      return redirect_to questions_path
    end
  end

  def check_favorite_permissions
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    unless logged_in?
      flash[:error] = t(:unauthenticated, :scope => "favorites.create")
      respond_to do |format|
        format.html do
          flash[:error] += ", [#{t("global.please_login")}](#{new_user_session_path})"
          redirect_to question_path(@question)
        end
        format.js do
          flash[:error] += ", <a href='#{new_user_session_path}'> #{t("global.please_login")} </a>"
          render(:json => {:status => :error, :message => flash[:error] }.to_json)
        end
        format.json do
          flash[:error] += ", <a href='#{new_user_session_path}'> #{t("global.please_login")} </a>"
          render(:json => {:status => :error, :message => flash[:error] }.to_json)
        end
      end
    end
  end


  def check_retag_permissions
    @question = current_group.questions.find_by_slug_or_id(params[:id])
    unless logged_in? && (current_user.can_retag_others_questions_on?(current_group) ||  current_user.can_modify?(@question))
      reputation = @question.group.reputation_constrains["retag_others_questions"]
      if !logged_in?
        flash[:error] = t("questions.show.unauthenticated_retag")
      else
        flash[:error] = I18n.t("users.messages.errors.reputation_needed",
                               :min_reputation => reputation,
                               :action => I18n.t("users.actions.retag_others_questions"))
      end
      respond_to do |format|
        format.html {redirect_to @question}
        format.js {
          render(:json => {:success => false,
                   :message => flash[:error] }.to_json)
        }
      end
    end
  end

  def set_active_tag
    @active_tag = "tag_#{params[:tags]}" if params[:tags]
    @active_tag
  end

  def check_age
    @question = current_group.questions.find_by_slug_or_id(params[:id])

    if @question.nil?
      @question = current_group.questions.first(:slugs => params[:id], :select => [:_id, :slug])
      if @question.present?
        head :moved_permanently, :location => question_url(@question)
        return
      elsif params[:id] =~ /^(\d+)/ && (@question = current_group.questions.first(:se_id => $1, :select => [:_id, :slug]))
        head :moved_permanently, :location => question_url(@question)
      else
        raise PageNotFound
      end
    end

    return if session[:age_confirmed] || is_bot? || !@question.adult_content

    if !logged_in? || (Date.today.year.to_i - (current_user.birthday || Date.today).year.to_i) < 18
      render :template => "welcome/confirm_age"
    end
  end

  def create_draft!
    draft = Draft.create!(:question => @question)
    session[:draft] = draft.id
    login_required
  end
end
