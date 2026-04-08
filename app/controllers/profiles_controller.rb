class ProfilesController < ApplicationController
  before_action :require_login

  def show
    @user  = current_user
    @teams = @user.tennis_teams.order(start_date: :desc)
    @stats = @user.tennis_stats.chronological

    # Computed totals row across all years
    if @stats.any?
      @totals = {
        matches_total: @stats.sum { |s| s.matches_total.to_i },
        matches_won:   @stats.sum { |s| s.matches_won.to_i },
        matches_lost:  @stats.sum { |s| s.matches_lost.to_i },
        sets_total:    @stats.any? { |s| s.sets_total } ? @stats.sum { |s| s.sets_total.to_i } : nil,
        sets_won:      @stats.any? { |s| s.sets_won }   ? @stats.sum { |s| s.sets_won.to_i }   : nil,
        sets_lost:     @stats.any? { |s| s.sets_lost }  ? @stats.sum { |s| s.sets_lost.to_i }  : nil,
        games_total:   @stats.any? { |s| s.games_total } ? @stats.sum { |s| s.games_total.to_i } : nil,
        games_won:     @stats.any? { |s| s.games_won }   ? @stats.sum { |s| s.games_won.to_i }   : nil,
        games_lost:    @stats.any? { |s| s.games_lost }  ? @stats.sum { |s| s.games_lost.to_i }  : nil,
        defaults:      @stats.any? { |s| s.defaults }    ? @stats.sum { |s| s.defaults.to_i }    : nil
      }
    end
  end
end
