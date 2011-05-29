# http://blog.stochasticbytes.com/2011/01/rubys-threaderror-deadlock-recursive-locking-bug/
require "thread"
class Mutex
  def lock_with_hack
    lock_without_hack
  rescue ThreadError => e
    if e.message != "deadlock; recursive locking"
      raise
    else
      unlock
      lock_without_hack
    end
  end
  alias_method :lock_without_hack, :lock
  alias_method :lock, :lock_with_hack
end

# patch for Omniauth::Facebook to be able to use the group credentials
OmniAuth.config.path_prefix = "/users/auth"
module OmniAuth
  module Strategies
    class Facebook
      def call!(env)
        host = env["HTTP_HOST"].split(':').first

        if (group = Group.where(:domain => host).only(:share).first) && group.share.fb_app_id.present? && group.share.fb_secret_key.present?
          self.client_id = group.share.fb_app_id
          self.client_secret = group.share.fb_secret_key

          Rails.logger.info "Using custom keys for #{group.name} (app_id=#{self.client_id})"
        end

        super
      end
    end
  end
end

