require 'open-uri'
module Jobs
  module Base
    include Magent::Async

    def create_badge(user, group, opts, check_opts = {})
      return if user.admin?

      unique = opts.delete(:unique) || check_opts.delete(:unique)

      ok = true
      if unique
        ok = user.find_badge_on(group, opts[:token], check_opts).nil?
      end

      return unless ok

      badge = user.badges.create(opts.merge({:group_id => group.id}))
      if !badge.valid?
        Rails.logger.info "Cannot create the #{badge.token} badge: #{badge.errors.full_messages}"
      else
        user.increment(:"membership_list.#{group.id}.#{badge.type}_badges_count" => 1)
        if badge.token == "editor"
          user.override(:"membership_list.#{group.id}.is_editor" => true)
        end
      end

      if !badge.new_record?
        Rails.logger.info ">> Created badge: #{badge.inspect}"
        if !user.email.blank? && user.notification_opts.activities
          Notifier.earned_badge(user, group, badge).deliver
        end

        if user.notification_opts.badges_to_twitter
          token = badge.name(user.language)
          group_name = group.name
          link = "http://" + group.domain # TODO: ssl

          txt = I18n.t('jobs.base.create_badge.send_twitter', :link => link, :token => "##{token}", :group_name => "##{group_name}") # TODO: link the twitter account
          user.twitter_client.update(txt)
        end
        if group.notification_opts.badges_to_twitter
          token = badge.name(user.language)
          group_name = group.name
          link ||= "http://" + group.domain # TODO: ssl

          txt = I18n.t('jobs.base.create_badge.group_send_twitter', :link => link,
                       :token => "##{token}", :user => user.login,
                       :group_name => "##{group_name}") # TODO: link the twitter account
          group.twitter_client.update(txt)
        end
      end
    end

    def shorten_url(url, entry)
      if entry.short_url.blank?
        begin
          link = open("http://bit.ly/api?url=#{CGI.escape(url)}").read
          entry.override(:short_url => link)
        rescue
          link = url
        end
      else
        link = entry.short_url
      end
      link
    end

    def make_status(text, link, limit)
      "#{text[0..limit-link.size]} #{link}"
    end
  end
end

