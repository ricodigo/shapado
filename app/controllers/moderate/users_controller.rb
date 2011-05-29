class Moderate::UsersController < ApplicationController
  before_filter :login_required, :except => [:show, :create]
  before_filter :moderator_required

  def index

  end

  protected
end
