class LandingController < ApplicationController
  
  skip_before_filter :check_user_authorization, :only => ['index', "thanks", "toggle_beta_test"]
  
  layout 'landing'

  def index
  end

  def thanks
    @user = User.find_by_idurl(params['user_id_url'])
    @is_new_user = params[:is_new_user]
  end

  def toggle_beta_test
    @user = User.find_by_idurl(params['user_id_url'])
    @user.wannabe_beta_tester = !@user.wannabe_beta_tester
    @user.save
    @is_new_user = params[:is_new_user]
    render(:action => "thanks")
  end

end
