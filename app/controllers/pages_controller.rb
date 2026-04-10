class PagesController < ApplicationController
  def home
    return redirect_to login_path unless current_user
    redirect_to teams_path
  end
end
