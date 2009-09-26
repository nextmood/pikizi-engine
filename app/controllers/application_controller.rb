# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "pikizi"


class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :user_authorized, :except => ['login', 'rpx_token_sessions_url', 'access_restricted']


  # get the current logged user, the active record object
  def get_logged_ar_user()
    if session[:logged_user_id]
      begin
        @current_ar_user ||= User.find(session[:logged_user_id])
      rescue
        logger.error "Oups I'can't find user with id=#{session[:logged_user_id].inspect}"
        nil
      end
    end
  end


  def self.release_version() "v 3.0 alpha 09/13/09"  end

  private

  def user_authorized
    #if ENV['RAILS_ENV']=="production"
    if get_logged_ar_user
      # there is an existing logged user
      redirect_to '/access_restricted' unless get_logged_ar_user.is_authorized?
    else
      if ENV['RAILS_ENV'] == "development"
        log_as_developper
      else
        redirect_to '/login'
      end
    end
  end

  def log_as_developper
    developper_key = "franck_dev"
    @current_ar_user = User.find_by_key(developper_key)
    @current_ar_user ||= User.create_from_key({ :identifier => developper_key,
                                                :name => developper_key,
                                                :username => developper_key,
                                                :email => "info@nextmood.com"},
                                              developper_key,
                                              "auth")
    session[:logged_user_id] = @current_ar_user.id
  end



end
