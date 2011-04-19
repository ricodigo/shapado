module Shapado
  module Models
    module Trackable
      extend ActiveSupport::Concern

      included do
        after_create :__on_create
        after_update :__on_update
        after_destroy :__on_destroy
      end

      module InstanceMethods
        private
        def __generate_trackable_info
          __fields_for_class(self.class, self.class.trackable_opts[:fields])
        end

        def __generate_target_info
          if target = __resolve_target
            klass = target.class
            if klass.respond_to?(:trackable_opts)
              __fields_for_class(klass, klass.trackable_opts[:fields])
            end
          end
        end

        def __fields_for_class(klass, fields)
          info = {}
          relations = klass.relations
          fields.each do |f|
            if relations.has_key?(f.to_s)
              if lookup = self.send(f)
                if lookup.respond_to?("name")
                  info[f] = lookup.send("name")
                else
                  info[f] = lookup["login"] || lookup["user_name"] || lookup["title"] || lookup["description"]
                end

                info["#{f}_type"] = lookup.class.to_s
                info["#{f}_id"] = lookup.id
                info["#{f}_param"] = lookup.to_param
              end
            else
              info[f] = self[f]
            end
          end

          info
        end

        def __resolve_trackable_scope
          scope_fields = self.class.trackable_opts[:scope]
          scope_fields = [scope_fields] if !scope_fields.is_a?(Array)

          scope = {}
          scope_fields.each do |f|
            scope[f] = self[f]
          end

          scope
        end

        def __resolve_target
          if track_in = self.class.trackable_opts[:target]
            self.send(track_in)
          end
        end

        def __on_create
          __create_activity("create")
        end

        def __on_update
          __create_activity("update")
        end

        def __on_destroy
          __create_activity("destroy")
        end

        def __create_activity(action, opts = {})
          Rails.logger.info "Adding #{action} activity for #{self.class}"
          Activity.create!(opts.merge({
            :action => action,
            :trackable_info => __generate_trackable_info,
            :target_info => __generate_target_info,
            :scope => __resolve_trackable_scope,
            :group_id => self[:group_id] || Thread.current[:current_group].try(:id),
            :user_id => Thread.current[:current_user].try(:id) || self[:user_id],
            :trackable => self,
            :target => __resolve_target,
            :user_ip => Thread.current[:current_ip]
          }))
        end
      end

      module ClassMethods
        def track_activities(*args)
          options = args.extract_options!

          trackable_opts[:fields] = args
          trackable_opts[:scope] = options[:scope]
          trackable_opts[:target] = options[:target]
        end

        def trackable_opts
          @trackable_opts ||= {}
        end
      end
    end
  end
end
