# Beta feedback from the Beta tag popup and the welcome card (Tara, Nov 24 2026).
class FeedbacksController < ApplicationController
  rate_limit to: 10, within: 1.hour, only: :create,
             with: -> { redirect_back fallback_location: root_path, alert: "Thanks! That's a lot of feedback at once. Please try again a bit later." }

  before_action :require_admin, only: :index

  # POST /feedback
  def create
    fb = Feedback.new(message: params[:message].to_s.strip, name: (params[:name].to_s.strip.presence unless current_user),
                      user: current_user, page: safe_page)
    if fb.save
      current_user&.update_column(:beta_welcomed_at, Time.current) unless current_user&.beta_welcomed_at
      redirect_back fallback_location: root_path, notice: "Thank you! Your feedback was sent."
    else
      redirect_back fallback_location: root_path, alert: "Please type a message first."
    end
  end

  # GET /admin/feedback
  def index
    @feedbacks = Feedback.includes(:user).order(created_at: :desc).limit(500)
  end

  # PATCH /beta/welcomed: "Got it" on the one-time welcome card.
  def welcomed
    current_user&.update_column(:beta_welcomed_at, Time.current)
    redirect_back fallback_location: teams_path
  end

  private

  # The page they were on, as a path only (no other sites, no query strings).
  def safe_page
    uri = URI.parse(request.referer.to_s)
    uri.host.nil? || uri.host == request.host ? uri.path.presence : nil
  rescue URI::InvalidURIError
    nil
  end
end
