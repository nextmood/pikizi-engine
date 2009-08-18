# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "pikizi"


class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :user_authorized, :except => ['login']


  # get the current logged user
  def get_logged_pkz_user()
    if session[:logged_user_id]
      @current_user ||= Pikizi::User.create_from_xml("U#{session[:logged_user_id]}")
    end
  end

  # save all objects in cache...
  def flush_caches
    Rails.cache.each { |key, cached_object| cached_object.save }
  end




  private

  def user_authorized
    if ENV['RAILS_ENV']=="production"
      # render 'users/access_restricted'
      render 'users/login'
    end
  end

end
