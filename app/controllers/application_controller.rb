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


  def self.release_version() "v 3.0 alpha 24 feb 2010"  end

  # this is used by the controller
  def get_product_selected(params)
    @knowledge = Knowledge.load(params[:knowledge_idurl])
    @products = @knowledge.products
    @products_idurls = @products.collect(&:idurl)
    @pidurls_selected = params[:select_product_idurls]
    @pidurls_selected ||= session[:pidurls_selected]
    @pidurls_selected ||= @products_idurls
    session[:pidurls_selected] = @pidurls_selected
    @products_selected = @products.select { |p| @pidurls_selected.include?(p.idurl) }
  end

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
    @current_user = User.load(User.compute_idurl("info@nextmood.com"))
    session[:logged_user_id] = @current_user.id
  end



end
