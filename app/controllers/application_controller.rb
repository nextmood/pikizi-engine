# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "pikizi"


class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :user_authorized?, :except => ['login']


  #after_filter :get_or_create_pkz_user

  def get_or_create_pkz_user(rpx_data=nil)
    unless @current_user

      session.inspect
      user_key = request.session_options[:id]

      raise "no user key !" unless user_key and user_key.size > 20
      @current_user = Pikizi::User.create_from_xml(user_key)
    end
    @current_user 
  end

  # save all objects in cache...
  def flush_caches
    Rails.cache.each { |key, cached_object| cached_object.save }
  end

  private

  # rpx_data -> {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  def user_authorized?
    if ENV['RAILS_ENV']=="production"
      if (rpx_data = RPXNow.user_data(params[:token],'2dde4557bd28343f445032c774264a0b8cd8b29a')).blank?
        if get_or_create_pkz_user(rpx_data).is_authorized?
          true
        else
          render("/users/access_restricted")
        end    
      else
       render("/users/login")
      end
    end
  end

end
