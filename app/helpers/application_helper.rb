# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def multiauth_dropdown(title)
    render 'shared/login_menu', :title => title
  end

  def with_facebook?
    return true if current_group.share.fb_active

    if request.host =~ Regexp.new("#{AppConfig.domain}$", Regexp::IGNORECASE)
      AppConfig.facebook["activate"]
    else
      false
    end
  end

  def context_panel_ads(group)
    if AppConfig.enable_adbard && request.domain == AppConfig.domain &&
        !Adbard.where(:group_id => current_group.id).first
      adbard = "<!--Ad Bard advertisement snippet, begin -->
        <script type='text/javascript'>
        var ab_h = '#{AppConfig.adbard_host_id}';
        var ab_s = '#{AppConfig.adbard_site_key}';
        </script>
        <script type='text/javascript' src='http://cdn1.adbard.net/js/ab1.js'></script>
        <!--Ad Bard, end -->"
    else
      adbard = ""
    end
    if group.has_custom_ads == true
      ads = []
      Ad.where(:group_id => group.id,:position =>'context_panel').each do |ad|
        ads << ad.code
      end
      ads << adbard
      return ads.join.html_safe unless ads.empty?
    end
  end

  def header_ads(group)
    if group.has_custom_ads
      ads = []
      Ad.where(:group_id => group.id,:position => 'header').each do |ad|
        ads << ad.code
      end
      return ads.join.html_safe  unless ads.empty?
    end
  end

  def content_ads(group)
    if group.has_custom_ads
      ads = []
      Ad.where(:group_id => group.id,:position => 'content').each do |ad|
        ads << ad.code
      end
      return ads.join.html_safe  unless ads.empty?
    end
  end

  def footer_ads(group)
    if group.has_custom_ads
      ads = []
      Ad.where(:group_id => group.id,:position => 'footer').each do |ad|
        ads << ad.code
      end
      return ads.join.html_safe  unless ads.empty?
    end
  end

  def language_desc(langs)
    (langs.kind_of?(Array) ? langs : [langs]).map do |lang|
      I18n.t("languages.#{lang}", :default => lang).capitalize
    end.join(', ')
  end

  def language_select(f, question, opts = {})
    selected = if question.new?
      logged_in? ? current_user.main_language : question.language
    else
      question.language
    end
    languages = logged_in? ? current_user.preferred_languages : current_group.languages

    f.select :language, languages_options(languages), {:selected => selected}, {:class => "select"}.merge(opts)
  end

  def language_select_tag(name = "language", value = nil, opts = {})
    languages = logged_in? ? current_user.preferred_languages : current_group.languages
    select_tag name, options_for_select(languages_options(languages)), {:value => value, :class => "select"}.merge(opts)
  end

  def languages_options(languages=nil, current_languages = [])
    languages = AVAILABLE_LANGUAGES-current_languages if languages.blank?
    locales_options(languages)
  end

  def locales_options(languages=nil)
    languages = AVAILABLE_LOCALES if languages.blank?

    languages.collect do |lang|
      [language_desc(lang), lang]
    end
  end

  def locales_roles
    roles = []
    Membership::ROLES.each do |role|
      roles << [I18n.t("roles.#{role}"), role]
    end
    roles
  end

  def tag_cloud(tags = [], options = {}, limit = nil)
    if tags.empty?
      tags = Question.tag_cloud({:group_id => current_group.id, :banned => false}.
                        merge(language_conditions.merge(language_conditions)), limit)
    end

    return '' if tags.size <= 2

    # Sizes: xxs xs s l xl xxl
    css = {1 => "xxs", 2 => "xs", 3 => "s", 4 => "l", 5 => "xl" }
    max_size = 5
    min_size = 1

    tag_class = options.delete(:tag_class) || "tag"

    lowest_value = tags.min { |a, b| a["count"].to_i <=> b["count"].to_i }
    highest_value = tags.max { |a, b| a["count"].to_i <=> b["count"].to_i }

    spread = (highest_value["count"] - lowest_value["count"])
    spread = 1 if spread == 0
    ratio = (max_size - min_size) / spread

    render 'shared/tag_cloud', :tags => tags, :css => css,
                               :lowest_value => lowest_value, :ratio => ratio,
                               :min_size => min_size, :tag_class => tag_class
  end

  def country_flag(code, name)
    if code
      image_tag("flags/flag_#{code.downcase}.gif", :title => name, :alt => "")
    end
  end

  def markdown(txt, options = {})
    raw = options.delete(:raw)
    body = render_page_links(txt.to_s, options)
    txt = if raw
      (defined?(RDiscount) ? RDiscount.new(body) : Maruku.new(body)).to_html
    else
      (defined?(RDiscount) ? RDiscount.new(body, :smart, :strict) : Maruku.new(sanitize(body))).to_html
    end

    if options[:sanitize] != false
      txt = defined?(Sanitize) ? Sanitize.clean(txt, SANITIZE_CONFIG) : sanitize(txt)
    end
    txt.html_safe
  end

  def render_page_links(text, options = {})
    group = options[:group]
    group = current_group if group.nil?
    in_controller = respond_to?(:logged_in?)

    text.gsub!(/\[\[([^\,\[\'\"]+)\]\]/) do |m|
      link = $1.split("|", 2)
      # FIXME mongoid .only(:title, :slug).where()
      page = Page.by_title(link.first, :group_id => group.id)


      if page.present?
        %@<a href="/pages/#{page.slug}" class="page_link">#{link[1] || page.title}</a>@
      else
        %@<a href="/pages/#{link.first.parameterize.to_s}?create=true&title=#{link.first}" class="missing_page">#{link.last}</a>@
      end
    end

    return text if !in_controller

    text.gsub(/%(\S+)%/) do |m|
      case $1
        when 'site'
          group.domain
        when 'site_name'
          group.name
        when 'current_user'
          if logged_in?
            link_to(current_user.login, user_path(current_user))
          else
            "anonymous"
          end
        when 'hottest_today'
          question = Question.where(:activity_at.gt => Time.zone.now.yesterday, :order => "hotness desc, views_count asc", :group_id => group.id, :select => [:slug, :title]).first
          if question.present?
            link_to(question.title, question_path(question))
          end
        else
          m
      end
    end
  end

  def format_number(number)
    return if number.nil?

    if number < 1000
      number.to_s
    elsif number >= 1000 && number < 1000000
      "%.01fK" % (number/1000.0)
    elsif number >= 1000000
      "%.01fM" % (number/1000000.0)
    end
  end

  def class_for_number(number)
    return if number.nil?

    if number >= 1000 && number < 10000
      "medium_number"
    elsif number >= 10000
      "big_number"
    elsif number < 0
      "negative_number"
    end
  end

  def shapado_auto_link(text, options = {})
    text = auto_link(text, :all,  { "rel" => 'nofollow', :class => 'auto-link' })
    if options[:link_users]
      text = TwitterRenderer.auto_link_usernames_or_lists(text, :username_url_base => "#{users_path}/", :suppress_lists => true)
    end

    text
  end

  def require_js(*files)
    content_for(:js) { javascript_include_tag(*files) }
  end

  def require_css(*files)
    content_for(:css) { stylesheet_link_tag(*files) }
  end

  def render_tag(tag)
    %@<span class="tag"><a href="#{questions_path(:tags => tag)}">#{@badge.token}</a></span>@
  end

  def class_for_question(question)
    klass = ""

    if question.accepted
      klass << "accepted"
    elsif !question.answered
      klass << "unanswered"
    end

    if logged_in?
      if current_user.is_preferred_tag?(current_group, *question.tags)
        klass << " highlight"
      end

      if current_user == question.user
        klass << " own_question"
      end
    end

    klass
  end

  def googlean_script(analytics_id, domain)
    "<script type=\"text/javascript\">
       var _gaq = _gaq || [];
       _gaq.push(['_setAccount', '#{analytics_id}']);
       _gaq.push(['_trackPageview'],['_setDomainName', '#{domain}']);

       (function() {
         var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
         ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
         (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(ga);
       })();
    </script>".html_safe
  end

  def logged_out_language_filter
    custom_lang = session["user.language_filter"]
    case custom_lang
    when "any"
      languages = "any"
    else
      languages = session["user.language_filter"] || I18n.locale.to_s.split('-').first
    end
    languages
  end

  def clean_seo_keywords(tags, text = "")
    if tags.size < 5
      text.scan(/\S+/) do |s|
        word = s.to_s.downcase
        if word.length > 3 && !tags.include?(word)
          tags << word
        end

        break if tags.size >= 5
      end
    end

    tags.join(', ')
  end

  def current_announcements(hide_time = nil)
    conditions = {:starts_at.lte => Time.zone.now.to_i,
                  :ends_at.gte => Time.zone.now.to_i,
                  :group_id.in => [current_group.id, nil]}
    if hide_time
      conditions[:updated_at] = {:$gt => hide_time}
    end

    if logged_in?
      conditions[:only_anonymous] = false
    end

    Announcement.order_by(:starts_at.desc).where(conditions)
  end

  def top_bar_links
    top_bar = raw(current_group.custom_html.top_bar)
    return [] if top_bar.blank?

    top_bar.split("\n").map do |line|
      render_page_links(line.strip)
    end
  end

  def gravatar(*args)
    super(*args).html_safe
  end

  def include_latex
    if current_group.enable_latex
      require_css 'http://fonts.googleapis.com/css?family=UnifrakturMaguntia'
      require_css domain_url(:custom => current_group.domain)+'/javascripts/mathscribe/jqmath-0.1.1.css'
      require_js domain_url(:custom => current_group.domain)+'/javascripts/mathscribe/jqmath-etc-0.1.1.min.js'
    end
  end

  def find_answer(question)
    if question.accepted
      question.answer
    else
      question.answers.order_by(:votes_average.asc).first
    end
  end

  def widget_css(widget)
    "<style type='text/css'>#{widget.settings["custom_external_css"]}</style>"
  end

  def widget_code(widget)
    path = embedded_widget_path(:id => widget.id)
    url = domain_url(:custom => current_group.domain) + path
    %@<iframe src="#{url}" height="200px"></iframe>@
  end

  def facebook_avatar(user)
    image_tag("http://graph.facebook.com/#{user.facebook_id}/picture")
  end

  def twitter_avatar(user)
    if user.user_info["twitter"]["image"]
      image_tag(user.user_info["twitter"]["image"])
    else
      gravatar(user.email.to_s, :size => 32)
    end
  end

  def identica_avatar(user)
    image_tag(user.user_info["identica"]["image"])
  end

  #TODO css for image tag size
  def linked_in_avatar(user)
    image_tag(user.user_info["linked_in"]["image"])
  end

  def suggestion_avatar(suggestion)
    if suggestion.class == User
      avatar_tag = if  suggestion.twitter_login?
                     twitter_avatar(suggestion)
                   elsif suggestion.identica_login?
                     identica_avatar(suggestion)
                   elsif suggestion.linked_in_login?
                     linked_in_avatar(suggestion)
                   else
                     gravatar(suggestion.email.to_s, :size => 32)
                   end
    else
      tag = Tag.where(:name => suggestion[0], :group_id => current_group.id).first
      avatar_tag = tag_icon_image_link(tag)
    end
    avatar_tag
  end

  def tag_icon_image_link(tag)
    image_tag(tag_icon_path(current_group, tag)) if tag.has_icon?
  end

  def common_follower(user, suggestion)
    if suggestion.class == User
      suggested_friend = suggestion
      friend = user.common_follower(suggested_friend)
    elsif (suggestion[1] && suggestion[1]["followed_by"])
      friend = suggestion[1]["followed_by"].sample
    end
    if friend
      raw(t('widgets.suggestions.followed_by', :user => "#{link_to friend.login, user_path(friend)}"))
    end
  end

  def suggestion_link(suggestion)
    if suggestion.class == User
      link_to(suggestion.login, user_path(suggestion))
    else
      tag_link(suggestion[0])
    end
  end

  def follow_suggestion_link(suggestion)
    if suggestion.class == User
      link_to "+ #{t("users.show.follow")}", follow_user_path(suggestion), :class => "follow_link", 'data-class' => "unfollow_link", 'data-title' => t("users.show.unfollow"), 'data-undo' => unfollow_user_path(suggestion)
    else
      follow_tag_link(Tag.where(:name => suggestion[0], :group_id => current_group.id).first)
    end
  end

  def follow_tag_link(tag)
    if logged_in?
      if current_user.preferred_tags_on(current_group).include?(tag.name)
        follow_class = 'unfollow-tag'
        follow_data = 'follow-tag'
        data_title = t("global.follow")
        title = t("global.unfollow")
        path = unfollow_tags_user_path(current_user)
        data_undo = follow_tags_user_path(current_user)
      else
        follow_data = 'unfollow-tag'
        follow_class = 'follow-tag'
        data_title = t("global.unfollow")
        title = t("global.follow")
        opt = 'add'
        path = follow_tags_user_path(current_user)
        data_undo = unfollow_tags_user_path(current_user)
      end
      link_to title, path, :class => follow_class, 'data-tag' => tag.name, 'data-class' => follow_data, 'data-title' => data_title, 'data-undo' => data_undo
    end
  end

  def tag_link(tag)
    link_to h(tag), tag_path(:id => tag), :rel => "tag", :title => t("questions.tags.tooltip", :tag => tag)
  end
end

