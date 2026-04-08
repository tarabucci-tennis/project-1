class SettingsController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
    @notifications = current_user.captain_notifications.recent.includes(:team_player, scheduled_match: :team)
    @unread_count = current_user.unread_notifications_count
  end

  def update_notification_preference
    pref = params[:preference]
    if User::NOTIFICATION_PREFS.include?(pref)
      current_user.update!(notification_preference: pref)
      redirect_back fallback_location: settings_path, notice: "Notification preference saved!"
    else
      redirect_back fallback_location: settings_path, alert: "Invalid preference."
    end
  end

  def mark_notifications_read
    current_user.captain_notifications.unread.update_all(read: true)
    redirect_to settings_path, notice: "All notifications marked as read."
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end
end
