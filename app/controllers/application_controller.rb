# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "pikizi"


class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  # This will run before the action. Redirecting aborts the action.
  before_filter :user_authorized?


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

  # this method is call back for rpxnow (this is triggered after login)
  # user_data
  # found: {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  # not found: nil (can happen with e.g. invalid tokens)
  def rpx_token
    raise "hackers?" unless data = RPXNow.user_data(params[:token])
    
    # self.current_user = User.find_by_identifier(data[:identifier]) || User.create!(data)
    redirect_to '/'
  end


  private

  # rpx_data -> {:name=>'John Doe', :username => 'john', :email=>'john@doe.com', :identifier=>'blug.google.com/openid/dsdfsdfs3f3'}
  def user_authorized?
    if ENV['RAILS_ENV']=="production"
      redirect_to '/access_restricted'
    end
  end

end
