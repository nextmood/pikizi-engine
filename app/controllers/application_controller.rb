# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'digest/md5'

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :check_user_authorization, :except => ['login', 'rpx_token_sessions_url', 'access_restricted']


  # get the current logged user, the active record object
  def get_logged_user()
    if session[:logged_user_idurl]
      begin
        @current_user ||= User.get_from_idurl(session[:logged_user_idurl])
      rescue
        logger.error "Oups I'can't find user with id=#{session[:logged_user_idurl].inspect}"
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
    developper_idurl = Digest::MD5.hexdigest(developper_rpx_email)
    unless @current_user = User.get_from_idurl(developper_idurl)
      # create a new user
      @current_user = User.create({:idurl => developper_idurl,
                                   :rpx_identifier => developper_rpx_identifier,
                                   :rpx_name => "Franck Patte",
                                   :rpx_username => "fpatte",
                                   :role => "admin",
                                   :rpx_email => developper_rpx_email})
      @current_user.link_back(nil)
    end
    session[:logged_user_idurl] = @current_user.idurl
  end



end
