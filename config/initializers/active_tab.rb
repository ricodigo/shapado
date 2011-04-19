module ActiveTab
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    unloadable

    def tabs(tabs)
      tabs.symbolize_keys!

      before_filter :set_active_tab

      private
      define_method(:set_active_tab) do
        @active_tab = tabs[request.env['action_dispatch.request.path_parameters'].symbolize_keys![:action].to_sym]
        @active_tab = tabs[:default] if tabs[:default] && @active_tab.nil?
        @action_tab = 'default_tab' if @active_tab.nil?
        @active_tab
      end
    end

    def subtabs(subtabs)
      subtabs.symbolize_keys!

      before_filter :set_active_subtab

      define_method(:current_order) do
        @current_order
      end
      helper_method :current_order

      define_method(:load_default_subtab) do
        action = request.env['action_dispatch.request.path_parameters'].symbolize_keys![:action]
        key = "#{params[:controller]}/#{action}"
        @subtabs = subtabs[action.to_sym]
        @active_subtab = params[:sort] || params[:tab]
        @store_subtab = !@subtabs.blank?

        if @store_subtab && @active_subtab.nil?
          if logged_in?
            @active_subtab, @current_order = (current_user.default_subtab || {})[key]
            @store_subtab = false
          end

          if @active_subtab.nil? && session[:subtab] && session[:subtab][key]
            @active_subtab, @current_order = session[:subtab][key]
            @store_subtab = logged_in?
          end

          if @active_subtab.nil?
            @active_subtab, @current_order = @subtabs.first
          end
        end
      end

      private
      define_method(:set_active_subtab) do
        load_default_subtab
        if !@subtabs.blank? && @current_order.nil?
          @subtabs.each do |st|
            if st.first.to_s == @active_subtab
              @current_order = st.last
              break
            end
          end
          @current_order ||= @subtabs.first.last
        end

        if @store_subtab
          subtab = [@active_subtab, @current_order]
          key = "#{request.env['action_dispatch.request.path_parameters'].symbolize_keys![:action]}"
          (session[:subtab] ||= {})[key] = subtab
          if logged_in?
            current_user.override({"default_subtab.#{key}" => subtab})
          end
        end
      end
    end
  end
end

ActionController::Base.class_eval do
  include ActiveTab
end
