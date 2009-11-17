class LandingController < ApplicationController
  
  skip_before_filter :check_user_authorization, :only => ['index']

  def index
    render :layout => 'landing' 
  end

end
