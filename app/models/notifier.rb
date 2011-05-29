class Notifier < ActionMailer::Base
  helper :application
  layout "notifications"

  def give_advice(user, group, question, following = false)
    scope = "mailers.notifications.give_advice"
    @language = language_for(user)
    set_locale @language
    if following
      subject I18n.t("friend_subject",
                     :scope => scope,
                     :question_title => question.title,
                     :locale => @language)
    else
      subject I18n.t("subject",
                     :scope => scope,
                     :question_title => question.title,
                     :locale => @language)
    end

    @user = user
    @question = question
    @group = group
    @following = following

    mail(:to => user.email, :from => from_email(group),
         :subject => @subject,
         :date => Time.now,
         :reply_to => @question.email) do |format|
      format.text
      format.html
    end
  end

  def new_answer(user, group, answer, following = false)
    scope = "mailers.notifications.new_answer"
    @language = language_for(user)
    set_locale @language
    if user == answer.question.user
      @subject = I18n.t("subject_owner", :scope => scope,
                        :title => answer.question.title,
                        :login => answer.user.login,
                        :locale => @language)
    elsif following
      @subject = I18n.t("subject_friend", :scope => scope,
                        :title => answer.question.title,
                        :login => answer.user.login,
                        :locale => @language)
    else
        @subject = I18n.t("subject_other", :scope => scope,
                          :title => answer.question.title,
                          :login => answer.user.login,
                          :locale => @language)
    end
    @user = user
    @answer = answer
    @question = answer.question
    @group = group
    mail(:to => user.email, :from => from_email(group),
         :subject => @subject, :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def new_comment(group, comment, user, question)
    @user = user
    @comment = comment
    @question = question
    @group = group
    @language = language_for(user)
    set_locale @language
    mail(:to => user.email, :from => from_email(group),
         :subject => I18n.t("mailers.notifications.new_comment.subject",
                            :login => comment.user.login,
                            :group => group.name, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def new_invitation(invitation_id)
    @invitation = Invitation.find(invitation_id)
    @group = @invitation.group
    @user = @invitation.user
    @language = @group.language
    set_locale @language
    mail(:to => @invitation.email, :from => from_email(@group),
         :subject => I18n.t("mailers.notifications.new_invitation.subject",
                            :user => @user.login,
                            :group => @group.name, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def new_feedback(user, subject, content, email, ip)
    @user = user
    @subject = subject
    @content = content
    @email = email
    @ip = ip
    @language = language_for(user)
    set_locale @language
    mail(:to => AppConfig.exception_notification["exception_recipients"],
         :from => "Shapado[feedback] <#{AppConfig.notification_email}>",
         :subject => "feedback: #{subject}",
         :date => Time.now) do |format|
      format.text
    end
  end

  def admin_login(ip, user_id)
    @admin = User.find(user_id)
    @language = language_for
    set_locale @language
    @subject =  I18n.t("mailers.notifications.admin_login.subject",
                       :locale => @language)
    @ip = ip
    mail(:to => AppConfig.exception_notification["exception_recipients"],
         :from => "Shapado[feedback] <#{AppConfig.notification_email}>",
         :subject => @subject,
         :date => Time.now) do |format|
      format.text
    end
  end

  def follow(user, followed, group)
    @user = user
    @followed = followed
    @group = group
    @language = language_for(user)
    set_locale @language
    mail(:to => followed.email ,
         :from => from_email(group),
         :subject => I18n.t("mailers.notifications.follow.subject",
                            :login => user.login,
                            :app => group.name, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def earned_badge(user, group, badge)
    @user = user
    @group = group
    @badge = badge
    @language = language_for(user)
    set_locale @language
    mail(:to => user.email ,
         :from => from_email(group),
         :subject => I18n.t("mailers.notifications.earned_badge.subject",
                            :group => group.name, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def created_flag(user, group, reason)
    @user = user
    @group = group
    @@language = language_for(user)
    set_locale @language
    @reason = I18n.t(reason, :scope=>"flags.form", :locale => @language)
    mail(:to => user.email ,
         :from => from_email(group),
         :subject => I18n.t("mailers.notifications.created_flag.subject",
                            :group => group.name, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def favorited(user, group, answer)
    @user = user
    @group = group
    @question = answer.question
    @answer = answer
    @language = language_for(@question.user)
    set_locale @language
    mail(:to => @question.user.email,
         :from => from_email(group),
         :subject => I18n.t("mailers.notifications.favorited.subject",
                            :login => user.login, :locale => @language),
         :date => Time.now) do |format|
      format.text
      format.html
    end
  end

  def report(user, report)
    @user = user
    @report = report
    @group = report.group
    @language = language_for(user)
    set_locale @language
    mail(:to => user.email,
         :from => from_email(@group),
         :subject => I18n.t("mailers.notifications.report.subject",
                     :group => report.group.name,
                     :app => AppConfig.application_name, :locale => @language),
         :date => Time.now) do |format|
      format.text
    end
  end

  private
  def initialize_defaults(method_name)
    super
    @method_name = method_name
  end

  def from_email(group)
    "#{group ? group.name : AppConfig.application_name} <notifications@#{Rails.application.config.action_mailer.default_url_options[:host]}>"
  end

  def language_for(user=nil)
    @language = if user && user.language
                 @language = user.language
               else
                 I18n.locale
               end
  end
end
