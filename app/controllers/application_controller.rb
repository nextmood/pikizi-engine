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
    begin
      logger.warn "session[:logged_user_id]=#{session[:logged_user_id].inspect}"
      if session[:logged_user_id]
        @current_user ||= User.find(session[:logged_user_id])
      end
    rescue
      #logger.error "Oups I'can't find user with id=#{session[:logged_user_id].inspect}"
      nil
    end
  end


  def self.release_version() "v 3.0 alpha 24 avril 2010"  end

  # this is used by the controller
  def get_products_selected
    raise "expecting knowledge to be set" unless @current_knowledge
    unless @products_selected
      @products = @current_knowledge.get_products
      if session[:product_ids_selected]
        @products_selected = @products.select { |p| session[:product_ids_selected].include?(p.id) }
      else
        session[:product_ids_selected] = (@products_selected = @products.first(5)).collect(&:id)
      end
    end
    [@products, @products_selected]
  end


  private

  def check_user_authorization
    @current_knowledge ||= Knowledge.first
    if get_logged_user
      # there is an existing logged user
      redirect_to '/access_restricted' unless get_logged_user.is_authorized
    elsif ENV['RAILS_ENV'] == "development"
        log_as_developper
    else
      logger.warn "there is no current user"
      redirect_to '/login'
    end
  end

  def log_as_developper
    @current_user = User.find_by_rpx_email("info@nextmood.com")
    raise "error no user indatabase?" unless @current_user
    session[:logged_user_id] = @current_user.id
  end



end
