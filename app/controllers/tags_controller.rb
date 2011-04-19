class TagsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  before_filter :moderator_required, :except => [:index, :show]

  def index
    params[:per_page] ||= "xl"
    @tags = current_scope.paginate(paginate_opts(params))

    respond_to do |format|
      format.html do
        set_page_title(t("layouts.application.tags"))
      end
      format.js do
        html = render_to_string(:partial => "tag_table", :locals => {:tag_table => @tags})
        render :json => {:html => html}
      end
      format.json  { render :json => @tags.to_json }
    end
  end

  def show
    @tag_names = params[:id].split("+")
    @tags =  current_scope.where(:name.in => @tag_names)
    @questions = current_group.questions.where( :tags.in => @tag_names ).
                                         paginate(paginate_opts(params))
  end

  def new
    @tag = Tag.new
  end

  def edit
    @tag = current_scope.where(:$or => [{:name => params[:id]}, {:_id => params[:id]}]).first
  end

  def create
    @tag = Tag.new
    @tag.safe_update(%w[name icon description], params[:tag])

    @tag.group = current_group
    @tag.user = current_user

    if @tag.save
      redirect_to tag_url(@tag)
    else
      render :action => :new
    end
  end

  def update
    @tag = current_scope.find(params[:id])
    @tag.safe_update(%w[name icon description], params[:tag])
    @name_changes = @tag.changes["name"]

    saved = @tag.save
    merge = (params[:merge] == "1" && !@tag.errors[:name].blank?)

    if saved || merge
      if @name_changes
        if merge
          Question.pull({group_id: @tag.group_id, :tags => {:$all => [@name_changes.first, @name_changes.last]}},
                        "tags" => @name_changes.first)
        end
        Question.override({group_id: @tag.group_id, :tags => @name_changes.first}, {"tags.$" => @name_changes.last})
      end
      redirect_to tag_url(:id => @tag.name)
    else
      render :action => "edit"
    end
  end

  def destroy
    @tag = current_scope.find(params[:id])
    tag_name = @tag.name
    @tag.destroy
    Question.pull({group_id: @tag.group_id, :tags => {:$in => [tag_name]}}, "tags" => tag_name)
    redirect_to tags_url
  end

  protected
  def current_scope
    if(!params[:q].blank?)
      current_group.tags.where(:name => /^#{Regexp.escape(params[:q])}/)
    else
      current_group.tags
    end
  end

end

