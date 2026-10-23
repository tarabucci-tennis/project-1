class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # NB: HTML pages are made non-cacheable by the NoHtmlCache middleware
  # (config/initializers/no_html_cache.rb) so deploys/data changes show up
  # immediately. We intentionally do NOT use `stale_when_importmap_changes`.

  helper_method :current_user

  before_action :record_member_visit

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  # One "day visited" per signed-in person per day (see User#record_visit!).
  def record_member_visit
    current_user&.record_visit!
  end

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end
end
