Shapado::Application.routes.draw do
  devise_for(:users,
             :path_names => {:sign_in => 'login', :sign_out => 'logout'},
             :controllers => {:registrations => 'users', :omniauth_callbacks => "multiauth/sessions"}) do
    match '/users/connect' => 'users#connect', :method => :post, :as => :connect
  end
  match '/connect' => 'users#social_connect', :method => :get, :as => :social_connect
  match '/invitations/accept' => 'invitations#accept', :method => :get, :as => :accept_invitation
  match '/disconnect_twitter_group' => 'groups#disconnect_twitter_group', :method => :get
  match '/group_twitter_request_token' => 'groups#group_twitter_request_token', :method => :get
  match 'confirm_age_welcome' => 'welcome#confirm_age', :as => :confirm_age_welcome
  match '/change_language_filter' => 'welcome#change_language_filter', :as => :change_language_filter
  match '/register' => 'users#create', :as => :register
  match '/signup' => 'users#new', :as => :signup
  match '/facts' => 'welcome#facts', :as => :facts
  match '/plans' => 'doc#plans', :as => :plans
  match '/chat' => 'doc#chat', :as => :chat
  match '/feedback' => 'welcome#feedback', :as => :feedback
  match '/send_feedback' => 'welcome#send_feedback', :as => :send_feedback
  match '/settings' => 'users#edit', :as => :settings
  match '/tos' => 'doc#tos', :as => :tos
  match '/privacy' => 'doc#privacy', :as => :privacy
  match '/widgets/embedded/:id' => 'widgets#embedded', :as => :embedded_widget
  match '/suggestions' => 'users#suggestions', :as => :suggestions
  match '/activities' => 'activities#index', :as => :activities
  get "mobile/index"

  resources :users do
    collection do
      get :autocomplete_for_user_login
      post :connect
    end

    member do
      get :unfollow
      get :follow
      post :follow_tags
      post :unfollow_tags
      get :feed
      get :expertise
      get :preferred
      get :by_me
      get :contributed
      get :answers
      get :follows
      get :activity
    end
  end

  resources :ads
  resources :adsenses
  resources :adbards
  resources :badges

  resources :searches, :path => "search", :as => "search"

  resources :pages do
    member do
      get :js
      get :css
    end
  end

  resources :announcements do
    collection do
      post :hide
    end
  end

  resources :imports do
    collection do
      post :send_confirmation
    end
  end

  get '/questions/:id/:slug' => 'questions#show', :as => :se_url, :id => /\d+/
  post '/questions/:id/start_reward' => "reward#start", :as => :start_reward
  get '/questions/:id/close_reward' => "reward#close", :as => :close_reward

  match '/answers(.format)' => 'answers#index', :as => :answers

  scope('questions') do
    resources :tags, :constraints => { :id => /\S+/ }
  end

  resources :questions do
    resources :votes
    resources :flags

    collection do
      get :tags_for_autocomplete
      get :unanswered
      get :related_questions
      get :random
    end

    member do
      get :solve
      get :unsolve
      get :flag
      get :follow
      get :unfollow
      get :history
      get :revert
      get :diff
      get :move
      put :move_to
      get :retag
      put :retag_to
      post :close
      put  :open
      get :remove_attachment

      get :twitter_share
    end

    resources :comments do
      resources :votes
    end

    resources :answers do
      resources :votes
      resources :flags
      member do
        get :favorite
        get :unfavorite
        get :flag
        get :history
        get :diff
        get :revert
      end

      resources :comments do
        resources :votes
      end
    end

    resources :close_requests
    resources :open_requests
  end



  match 'questions/tags/:tags' => 'tags#show', :as => :question_tag
#   match 'questions/unanswered/tags/:tags' => 'questions#unanswered'

  resources :groups do
    collection do
      get :autocomplete_for_group_slug
    end

    member do
      get :allow_custom_ads
      get :disallow_custom_ads
      get :close
      get :accept
    end
  end

  resources :invitations do
    member do
      post :revoke
    end
  end

  scope '/manage' do
    resources :widgets do
      member do
        post :move
      end
    end

    resources :constrains_configs
    resources :members
  end

  scope '/manage', :as => 'manage' do
    controller 'admin/manage' do
      match 'social' => :social
      match 'properties' => :properties
      match 'theme' => :theme
      match 'actions' => :actions
      match 'stats' => :stats
      match 'reputation' => :reputation
      match 'domain' => :domain
      match 'content' => :content
      match 'invitations' => :invitations
    end
  end

  namespace :moderate do
    resources :questions do
      collection do
        get :flagged
        get :to_close
        get :to_open
        put :manage
      end
    end
    resources :answers
    resources :users
  end

  match '/moderate' => 'moderate/questions#index'
#   match '/search' => 'searches#index', :as => :search
  match '/about' => 'groups#show', :as => :about
  root :to => 'questions#index'
  match '/:controller(/:action(/:id))'
end
