class TennisTeam < ApplicationRecord
  belongs_to :user

  TENNISLINK_STANDINGS_URL = "https://tennislink.usta.com/Leagues/Main/StatsAndStandings.aspx".freeze

  def tennislink_standings_url
    return nil if tennislink_team_id.blank?

    "#{TENNISLINK_STANDINGS_URL}?t=#{tennislink_team_id}"
  end
end
