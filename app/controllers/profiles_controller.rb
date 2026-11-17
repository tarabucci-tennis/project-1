class ProfilesController < ApplicationController
  # Fewest matches before a win % or a "best" pick is shown (Tara, Nov 16 2026).
  MIN_SAMPLE = 3
  before_action :require_login

  # GET /profile — your own profile
  def show
    @user  = current_user
    @teams = current_user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @teams = current_user.tennis_teams.order(start_date: :desc) if @teams.empty?
    @is_self = true
    @shared_teams = []
    split_teams(@user, @teams)
    load_record(@user)
    render :player
  end

  # POST /profile/deltri — save your Del-Tri player link and pull your history.
  def connect_deltri
    url = params[:deltri_player_url].to_s.strip
    current_user.update(deltri_player_url: url.presence)

    if url.blank?
      redirect_to settings_path, notice: "Removed your league link."
      return
    end

    result = DeltriPlayerImport.new(current_user).call
    if result.imported.any?
      redirect_to settings_path, notice: "Pulled your league matches — #{result}"
    else
      redirect_to settings_path, alert: "Couldn't read that league link. #{result.notes.join('; ')}"
    end
  end

  # POST /profile/deltri/refresh — pull your league-site matches again from
  # the link saved in Settings (the link itself never shows on the profile).
  def refresh_deltri
    unless current_user.deltri_player_url.present?
      return redirect_to settings_path, alert: "Add your league player-page link first."
    end

    result = DeltriPlayerImport.new(current_user).call
    if result.imported.any?
      redirect_to profile_path(anchor: "league-history"), notice: "Refreshed your league matches."
    else
      redirect_to profile_path(anchor: "league-history"), alert: "Couldn't refresh right now. #{result.notes.join('; ')}"
    end
  end

  # GET /settings — your private links and your synced calendar.
  def settings
    @user = current_user
    @external_events = @user.external_events.upcoming.limit(30)
  end

  # POST /profile/city — optional: the city shown next to your name.
  # Blank removes it. Only ever your own (current_user).
  def update_city
    city = params[:city].to_s.squish.first(60)
    current_user.update(location: city.presence)
    redirect_to profile_path, notice: city.present? ? "Saved your city." : "Removed your city."
  end

  # POST /profile/calendar — save your Google Calendar iCal link and pull the
  # tennis events (matches, clinics, friendlies) from it. Blank removes it.
  def connect_calendar
    url = params[:ical_url].to_s.strip
    current_user.update(ical_url: url.presence)

    if url.blank?
      current_user.external_events.delete_all
      redirect_to settings_path, notice: "Removed your Google Calendar link."
      return
    end

    result = GoogleCalendarImport.new(current_user).call
    if result.error
      redirect_to settings_path, alert: "Couldn't read that calendar link (#{result.error}). Make sure it's the secret iCal address from Google Calendar settings."
    else
      redirect_to settings_path, notice: "Synced #{result.imported} event#{'s' unless result.imported == 1} from your calendar (#{result.tennis} tennis)."
    end
  end

  # GET /players/:id — teammate's profile
  def player
    @user = User.find_by(id: params[:id])
    unless @user
      # A merged-away record: forward to the person it was merged into.
      kept = User.find_by(id: MergedUser.current_id_for(params[:id]))
      return redirect_to(player_path(kept, team: params[:team].presence), status: :moved_permanently) if kept

      redirect_to teams_path, alert: "Player not found."
      return
    end

    @teams = @user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @is_self = (@user.id == current_user.id)
    split_teams(@user, @teams)

    # Optional team filter: the "Stats for …" dropdown scopes the match-line
    # stats to one of this player's teams so you can flip between them without
    # leaving the page. Nil = "All Teams" (the default combined view).
    @selected_team = @teams.detect { |t| t.id.to_s == params[:team].to_s } if params[:team].present?

    # Find teams you share with this player
    my_team_ids = current_user.member_teams.pluck(:id)
    their_team_ids = @user.member_teams.pluck(:id)
    shared_ids = my_team_ids & their_team_ids
    @shared_teams = TennisTeam.where(id: shared_ids).order(start_date: :desc)
    load_record(@user, team: @selected_team)
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end

  # Current teams (what My Teams shows) first, past seasons separately: a
  # team is past when it's archived or this player's spot on it was
  # archived with an old season.
  def split_teams(user, teams)
    archived_ids = user.team_memberships.where.not(archived_season: [ nil, "" ]).pluck(:tennis_team_id)
    active_ids = user.team_memberships.where(archived_season: [ nil, "" ]).pluck(:tennis_team_id)
    teams = teams.to_a.uniq
    current, past = teams.partition { |t| !t.archived? && (active_ids.include?(t.id) || !archived_ids.include?(t.id)) }
    @current_teams = TennisTeam.group_by_league(current).values.flatten
    @past_teams = past.sort_by { |t| [ t.start_date || Date.new(0), t.name.to_s ] }.reverse
  end

  def load_record(user, team: nil)
    @record = build_record(user, team: team)
    @playing_stats = build_playing_stats(@record)
    @league_year_stats = @record.by_league_year
    @year_stats = @record.by_year
    @deltri_matches = user.player_matches.chronological.group_by { |pm| [ pm.league, pm.division ] }
    @counted_elsewhere_ids = @record.duplicate_player_match_ids
  end

  # Every stat on the profile comes from one PlayerRecord (see
  # app/services/player_record.rb), so the numbers always agree.
  def build_record(user, team: nil)
    PlayerRecord.new(user, team: team)
  end

  def build_playing_stats(record)
    entries = record.entries
    user = record.user

    # Always return a well-formed hash so the view can show the stat
    # structure even before any matches have been played. Empty sections
    # (partners, recent matches) degrade gracefully in the view.
    stats = {
      overall:        { won: 0, lost: 0, total: 0, pct: 0 },
      singles:        { won: 0, total: 0, pct: 0 },
      doubles:        { won: 0, total: 0, pct: 0 },
      by_line:        {},
      partners:       [],
      best_partner:   nil,
      recent:         [],
      usual_doubles_line:    nil,  # e.g. "2D" — the line this player plays most often
      matches_played_by_team: [],  # [{ team_name:, count: }]
      matches_played_total:   0,
      from_league_sites:      record.league_site_entries.size,
      is_empty:       entries.empty?
    }

    return stats if entries.empty?

    overall = PlayerRecord.tally(entries)
    stats[:overall] = overall.merge(pct: pct(overall[:won], overall[:total]))

    singles, doubles = entries.partition(&:singles)
    stats[:singles] = { won: singles.count(&:won?), total: singles.size, pct: pct(singles.count(&:won?), singles.size) }
    stats[:doubles] = { won: doubles.count(&:won?), total: doubles.size, pct: pct(doubles.count(&:won?), doubles.size) }

    # Win % by line position (only rows that say which line)
    entries.select(&:line_label).group_by(&:line_label).each do |label, group|
      w = group.count(&:won?)
      stats[:by_line][label] = { won: w, total: group.size, pct: pct(w, group.size) }
    end

    # Usual doubles line — the doubles position this player plays most often.
    top = doubles.filter_map(&:position).tally.max_by { |_, count| count }
    stats[:usual_doubles_line] = "#{top.first}D" if top

    # Matches per team — same definition as everywhere else (one per line).
    team_counts = entries.group_by { |e| e.team_name.presence || e.league }.transform_values(&:size)
    stats[:matches_played_by_team] = team_counts.map { |name, count| { team_name: name, count: count } }
                                                .sort_by { |t| -t[:count] }
    stats[:matches_played_total] = entries.size

    # Doubles partner stats
    # Grouped by person, not by spelling: league websites type partner names
    # as text ("Joanne Steinberg"), so they're matched to the Court Report
    # player ("JoAnne Steinberg") ignoring case, spacing and accents, and
    # shown with the Court Report spelling.
    partner_data = Hash.new { |h, k| h[k] = { won: 0, lost: 0, total: 0 } }
    display_name = {}
    doubles.sort_by { |e| e.source == :court_report ? 0 : 1 }.each do |e|
      e.partners.each do |name|
        key = name.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.squish
        display_name[key] ||= name
        partner_data[key][:total] += 1
        partner_data[key][:won] += 1 if e.won?
        partner_data[key][:lost] += 1 if e.lost?
      end
    end
    # Percentages and "best" need a real sample: under MIN_SAMPLE matches a
    # partner shows a record but no %, and can't be Best Partner (a 1-0
    # partnership isn't "best"). Qualified partners first, best % first.
    rows = partner_data.map do |key, data|
      { name: display_name[key], won: data[:won], lost: data[:lost], total: data[:total], pct: pct(data[:won], data[:total]),
        qualified: data[:total] >= MIN_SAMPLE }
    end
    qualified, small = rows.partition { |p| p[:qualified] }
    stats[:partners] = qualified.sort_by { |p| [ -p[:pct], -p[:total], p[:name].to_s ] } +
                       small.sort_by { |p| [ -p[:total], -p[:won], p[:name].to_s ] }
    stats[:best_partner] = qualified.any? ? stats[:partners].first : nil

    # Recent matches (last 5)
    stats[:recent] = entries.last(5).reverse.map do |e|
      {
        date: e.date, opponent: e.opponent,
        team: e.team_name, line_label: e.line_label, result: e.result, score: e.score,
        players: e.player_ids, opponents: e.opponents, from_league_site: e.source == :league_site
      }
    end

    # Resolve opponent names to Court Report players so they can link to that
    # player's stats. Names we don't have a profile for stay as plain text.
    all_names = stats[:recent].flat_map { |m| split_opponent_names(m[:opponents]) }.uniq
    id_by_name = {}
    if all_names.any?
      User.where("LOWER(name) IN (?)", all_names.map(&:downcase))
          .each { |u| id_by_name[u.name.downcase] = u.id }
    end
    stats[:recent].each do |m|
      m[:opponent_players] = split_opponent_names(m[:opponents]).map do |name|
        { name: name, id: id_by_name[name.downcase] }
      end
    end

    stats
  end

  # Splits a free-text opponents string ("Jane Smith / Mary Jones") into
  # individual names, dropping blanks and obvious placeholders ("N/A",
  # "Default", "TBD") that early seed rows carried.
  def split_opponent_names(str)
    str.to_s.split(%r{[/,]}).map(&:strip).reject do |n|
      n.blank? || n.match?(/\A(n\/?a|default|tbd|—|-)\z/i) || n.downcase.include?("default")
    end
  end

  def pct(won, total)
    return 0 if total == 0
    (won.to_f / total * 100).round(0)
  end
end
