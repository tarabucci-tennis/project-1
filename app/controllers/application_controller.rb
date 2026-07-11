class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # NB: intentionally NOT using `stale_when_importmap_changes` — it etags pages
  # by the importmap digest, so HTML/view changes (which don't touch the
  # importmap) were served stale (304) after a deploy.

  # Never let the browser cache HTML pages, so a deploy is seen immediately
  # (no more stale "old version" after an update). Fingerprinted CSS/JS/images
  # are served separately by Propshaft and stay cached for speed.
  after_action :no_html_caching

  helper_method :current_user

  private

  def no_html_caching
    return unless request.format.html?
    # Set via the cache_control hash (not a raw header) so Rails doesn't rebuild
    # over it. no-cache makes Rack::ETag skip adding an ETag, so the browser has
    # no validator to 304 against and always refetches the current page.
    response.cache_control.replace(no_cache: true, extras: [ "no-store" ])
    response.headers["Pragma"] = "no-cache"
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
