# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'digest/md5'

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :check_user_authorization


  # get the current logged user, the active record object
  def get_logged_user()
    if session[:logged_user_id]
      begin
        @current_user ||= User.load(session[:logged_user_id])
      rescue
        logger.error "Oups I'can't find user with id=#{session[:logged_user_id].inspect}"
        nil
      end
    end
  end


  def self.release_version() "v 3.0 alpha 11/1/09"  end

  private

  def check_user_authorization
    if get_logged_user
      # there is an existing logged user
      redirect_to '/access_restricted' unless get_logged_user.is_authorized
    elsif ENV['RAILS_ENV'] == "development"
        log_as_developper
    else
        redirect_to '/login'
    end
  end

  def log_as_developper
    developper_rpx_identifier = "#001"
    developper_rpx_email = "info@nextmood.com"
    developper_idurl = User.compute_idurl(developper_rpx_email)
    unless @current_user = User.load(developper_idurl)
      # create a new user

      @current_user = User.first_create(:rpx_identifier => developper_rpx_identifier,
                                        :rpx_email => developper_rpx_email,
                                        :rpx_username => "fpatte",
                                        :rpx_name => "Franck Patte",
                                        :role => "admin")
    end
    session[:logged_user_id] = @current_user.id
  end



end
