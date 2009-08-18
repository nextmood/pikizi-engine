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


  # get the current logged user, the xml object
  def get_logged_pkz_user()
    if session[:logged_user_id]
      @current_pkz_user ||= Pikizi::User.create_from_xml("U#{session[:logged_user_id]}")
    end
  end

  # get the current logged user, the active record object
  def get_logged_ar_user()
    if session[:logged_user_id]
      puts "******* looking for ar user=#{session[:logged_user_id]}"
      @current_ar_user ||= User.find(session[:logged_user_id])
    end
  end

  # save all objects in cache...
  def flush_caches
    Rails.cache.each { |key, cached_object| cached_object.save }
  end


  private

  def user_authorized
    #if ENV['RAILS_ENV']=="production"
    if get_logged_ar_user
      # there is an existing logged user
      redirect_to '/access_restricted' unless get_logged_ar_user.is_authorized?
    else
      # render 'users/access_restricted'
      redirect_to '/login'
    end
  end

end
