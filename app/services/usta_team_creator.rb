# Creates (or finds) a Court Report team from a TennisLink "Team Summary"
# export, so a player can add any USTA team they're on with one file:
# league, flight, level, season dates, home club, match format, captain and
# co-captain come from the file's header; standings, matches and the roster
# are then saved by UstaTeamSummaryImport.
#
# The export doesn't say which team in the standings is the uploader's, so the
# caller passes the chosen `team_name` (one of the standings rows). Phone
# numbers and emails in the file are never stored.
#
# Safe to run again: an existing team with the same name is reused and only
# blank fields are filled in.
class UstaTeamCreator
  attr_reader :team

  def initialize(parsed, team_name:, user:)
    @parsed = parsed
    @team_name = team_name.to_s.squish
    @user = user
  end

  def existing_team
    TennisTeam.where(league_category: "USTA").where("LOWER(name) = ?", @team_name.downcase).first
  end

  def call
    ActiveRecord::Base.transaction do
      @team = existing_team || TennisTeam.new(name: @team_name, league_category: "USTA", user: @user)
      fill_details
      @team.save!
      add_leaders
      add_uploader
      UstaTeamSummaryImport.new(@team, @parsed).apply!
    end
    @team
  end

  private

  def fill_details
    flight = @parsed.flight.to_s
    {
      league_name:        ("USTA #{@parsed.league}" if @parsed.league.present?),
      team_type:          @parsed.league.presence,
      flight:             flight.presence,
      rating:             flight[/(\d\.\d)/, 1]&.to_d,
      gender:             gender_from(flight),
      section:            @parsed.section.presence,
      district:           @parsed.district.to_s.titleize.presence,
      home_court:         @parsed.facility.presence,
      home_court_address: @parsed.facility_address.presence,
      line_format:        @parsed.format.presence,
      start_date:         @parsed.season_start,
      season_name:        season_name,
      standings_style:    "usta"
    }.each do |attr, value|
      @team[attr] = value if @team[attr].blank? && !value.nil?
    end
  end

  def gender_from(flight)
    return "Mixed" if flight.match?(/mixed/i)
    return "Women's" if flight.match?(/women/i)
    "Men's" if flight.match?(/\bmen/i)
  end

  def season_name
    start = @parsed.season_start
    return nil unless start
    if @parsed.league.to_s.match?(/winter/i)
      "Winter #{start.year}-#{(start.year + 1).to_s[-2..]}"
    else
      start.year.to_s
    end
  end

  def add_leaders
    { @parsed.captain => "captain", @parsed.co_captain => "co_captain" }.each do |name, role|
      next if name.blank?
      user = find_or_create_user(name)
      membership = @team.team_memberships.find_by(user: user)
      if membership.nil?
        TeamMembership.create!(user: user, tennis_team: @team, role: role)
      elsif membership.role == "player"
        membership.update!(role: role)
      end
    end
  end

  def add_uploader
    return if @team.team_memberships.exists?(user: @user)
    TeamMembership.create!(user: @user, tennis_team: @team, role: "player")
  end

  def find_or_create_user(name)
    User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
  end
end
