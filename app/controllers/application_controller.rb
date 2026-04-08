class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  layout "courtreport"

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end
end
