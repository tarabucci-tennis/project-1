class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Never let the browser cache HTML pages, so a deploy is seen immediately
  # (no more stale "old version" after an update). Fingerprinted CSS/JS/images
  # are served separately by Propshaft and stay cached for speed.
  after_action :no_html_caching

  helper_method :current_user

  private

  def no_html_caching
    return unless request.format.html?
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end
end
