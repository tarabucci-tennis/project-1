class LineupsController < ApplicationController
  before_action :require_login
  before_action :set_team_and_match, except: [ :dashboard ]

  # GET /lineups — dashboard showing all upcoming matches across user's teams
  def dashboard
    owned_team_ids  = current_user.tennis_teams.pluck(:id) rescue []
    member_team_ids = current_user.member_teams.pluck(:id) rescue []
    @teams = TennisTeam.where(id: (owned_team_ids + member_team_ids).uniq)
    @upcoming = []

    @teams.each do |team|
      next unless team.respond_to?(:matches)
      team.matches.where("match_date >= ?", Date.current).order(:match_date).each do |match|
        lineup = match.lineup rescue nil
        slot   = lineup&.lineup_slots&.find_by(user_id: current_user.id) rescue nil
        @upcoming << {
          team: team,
          match: match,
          lineup: lineup,
          published: lineup&.published?,
          my_slot: slot,
          is_captain: team.respond_to?(:captain?) ? team.captain?(current_user) : false
        }
      end
    end

    @upcoming.sort_by! { |u| u[:match].match_date }
  end

  # GET /teams/:team_id/matches/:match_id/lineup/edit — captain sets lineup
  def edit
    unless @team.can_set_lineup?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains and co-captains can set lineups."
    end

    @lineup = @match.lineup || @match.create_lineup!
    @members = @team.members.order(:name)

    # Top up any missing slots so the lineup always has the canonical
    # 1S + 4×2D structure (9 total). This is idempotent and preserves
    # any existing slots, so if a stray slot was saved from a broken
    # earlier edit session, we'll fill in what's missing instead of
    # only creating slots when the lineup is completely empty.
    ensure_default_slots(@lineup)

    @slots = @lineup.lineup_slots.includes(:user).order(position: :asc)
    load_last_week
    load_usual
    load_subs
    load_pair_records
  end

  # PATCH /teams/:team_id/matches/:match_id/lineup — captain saves lineup
  def update
    unless @team.can_set_lineup?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains and co-captains can set lineups."
    end

    @lineup = @match.lineup || @match.create_lineup!

    # Make sure all 9 slots exist before we try to update them
    ensure_default_slots(@lineup)

    ActiveRecord::Base.transaction do
      if params[:slots].present?
        # Who goes where. A blank pick removes the player from that line.
        wanted = {}
        params[:slots].each do |slot_id, slot_data|
          next unless slot_data.key?(:user_id)
          new_user_id = slot_data[:user_id].presence
          # "Write in a sub": a player who isn't on the roster. Reuse the person
          # if the name is already known (any capitalisation), otherwise add
          # them as a name-only player. Subs are not added to the roster.
          # No name typed = leave that line as it was.
          if new_user_id == SUB_OPTION
            name = slot_data[:sub_name].to_s.squish.first(60)
            next if name.blank?
            new_user_id = sub_user_for(name).id
          end
          wanted[slot_id.to_s] = new_user_id&.to_i
        end

        twice = wanted.values.compact.tally.select { |_, n| n > 1 }.keys
        if twice.any?
          names = User.where(id: twice).pluck(:name).to_sentence
          return redirect_to edit_team_match_lineup_path(@team, @match),
                             alert: "#{names} can only be on one line. Nothing was saved, please fix and save again."
        end

        # Take everyone who's moving off their old line first, so a player can
        # move from one line to another in the same save.
        moving = @lineup.lineup_slots.where(id: wanted.keys).select { |slot| slot.user_id != wanted[slot.id.to_s] }
        moving.each { |slot| slot.update!(user_id: nil) if slot.user_id }
        moving.each { |slot| slot.update!(user_id: wanted[slot.id.to_s]) if wanted[slot.id.to_s] }

        params[:slots].each do |slot_id, slot_data|
          slot = @lineup.lineup_slots.find(slot_id)
          next unless slot_data.key?(:confirmed)

          # Captain override: "Already confirmed" checkbox
          if slot_data[:confirmed] == "1"
            slot.update!(confirmation: "confirmed", confirmed_at: slot.confirmed_at || Time.current) unless slot.confirmed?
          else
            # Unchecked — reset to pending so the player can be asked
            slot.update!(confirmation: "pending", confirmed_at: nil) unless slot.pending?
          end
        end
      end

      # Publish if requested
      @emailed = 0
      if params[:publish] == "true" && !@lineup.published?
        @lineup.update!(published: true, published_at: Time.current)

        # Only email players who are NOT already confirmed by the captain
        # AND have a real user assigned, and only when the server can send
        # email (SMTP set up). Pre-confirmed and empty slots are skipped.
        if email_ready?
          @lineup.lineup_slots.includes(:user).where(confirmation: "pending").each do |slot|
            next if slot.user.nil?
            next unless slot.user.email.present?
            LineupMailer.lineup_posted(slot).deliver_later
            @emailed += 1
          end
        end
      end
    end

    # Say only what really happened; texting the lineup is the Share lineup button.
    if params[:publish] == "true"
      notice = "Lineup posted. Tap Share lineup to text it to your team."
      notice += " We also emailed #{@emailed} #{'player'.pluralize(@emailed)} to confirm." if @emailed.positive?
      redirect_to team_match_path(@team, @match), notice: notice
    else
      redirect_to team_path(@team), notice: @lineup.published? ? "Lineup saved. Players see the changes in Court Report." : "Lineup saved as a draft (not posted yet)."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_team_match_lineup_path(@team, @match), alert: "Error: #{e.message}"
  end

  # PATCH /teams/:team_id/matches/:match_id/lineup/confirm — player confirms
  def confirm
    @lineup = @match.lineup
    unless @lineup&.published?
      return redirect_to team_path(@team), alert: "No lineup posted yet."
    end

    slot = @lineup.slot_for(current_user)
    unless slot
      return redirect_to team_path(@team), alert: "You're not in the lineup for this match."
    end

    new_status = params[:status]
    if %w[confirmed declined].include?(new_status)
      slot.update!(confirmation: new_status, confirmed_at: Time.current)
    end

    redirect_to team_path(@team), notice: new_status == "confirmed" ? "You're confirmed! See you on the court." : "Response recorded."
  end

  private

  # Email goes out only once the server has a Gmail login (SMTP_USERNAME / SMTP_PASSWORD).
  def email_ready?
    ENV["SMTP_USERNAME"].present? && ENV["SMTP_PASSWORD"].present?
  end

  def set_team_and_match
    @team = TennisTeam.find(params[:team_id])
    @match = @team.matches.find(params[:match_id])
  end

  def require_login
    redirect_to login_path unless current_user
  end

  # Top up the lineup so it has the canonical slot structure for this
  # team's league format:
  #   - USTA:       1 singles + 4 doubles = 9 slots
  #   - Inter-Club: 6 doubles               = 12 slots
  #   - Del-Tri:    6 doubles               = 12 slots
  #
  # Idempotent: counts existing slots per (line_type, position) and
  # creates whatever is missing. New slots are created with
  # user_id=NULL so the unique (lineup_id, user_id) index doesn't
  # clash when multiple default slots need to coexist for the same
  # doubles line. Captain fills them in from the dropdowns.
  # Lineups barely change week to week, so a new (empty) lineup starts from the
  # team's most recent earlier lineup: @prefill maps slot id => player, shown as
  # the dropdown's pick until the captain saves. Changing a line is how a sub
  # goes in. Players no longer on the team aren't carried over.
  def load_last_week
    @prefill = {}
    @last_week = {}
    previous = Lineup.joins(:match)
                     .where(matches: { tennis_team_id: @team.id })
                     .where("matches.match_date < ?", @match.match_date)
                     .where(id: LineupSlot.where.not(user_id: nil).select(:lineup_id))
                     .order("matches.match_date DESC").first
    return unless previous

    @prefill_from = previous.match
    member_ids = @members.map(&:id).to_set
    before = previous.lineup_slots.includes(:user).order(:id).group_by { |s| [ s.line_type, s.position ] }
    now = @slots.sort_by(&:id).group_by { |s| [ s.line_type, s.position ] }
    fill = @slots.all? { |s| s.user_id.nil? }
    now.each do |key, slots|
      slots.zip(before[key] || []).each do |slot, old|
        next unless old&.user
        @last_week[slot.id] = old.user.name
        @prefill[slot.id] = old.user_id if fill && member_ids.include?(old.user_id)
      end
    end
    @prefill_from = nil if @prefill.empty? && @last_week.empty?
  end

  # Once a team has a few matches with line scores, an empty lineup is filled
  # with who has played each line most (instead of just last week's), and each
  # line shows its most frequent players with a count ("6 of 8").
  # Players who said they can't play this match are left out of the fill.
  def load_usual
    @usual = UsualLineup.new(@team, before: @match.match_date)
    @prefill_kind = :last_week if @prefill.any?
    return unless @usual.enough? && @slots.all? { |s| s.user_id.nil? }

    out = @match.availabilities.where(status: "out").pluck(:user_id)
    allowed = @members.map(&:id).to_set - out
    by_line = @slots.sort_by(&:id).group_by { |s| [ s.line_type, s.position ] }
    picks = @usual.suggest(by_line.transform_values(&:size), allowed)
    return if picks.empty?

    @prefill = {}
    by_line.each do |key, slots|
      slots.zip(picks[key]).each { |slot, uid| @prefill[slot.id] = uid if uid }
    end
    @prefill_kind = :usual
  end

  # How each doubles pair has done together on this team ("4-1, usually
  # Doubles 2"), keyed "smallerId-largerId" so the page can show it as soon as
  # the captain picks two partners.
  def load_pair_records
    @pair_records = DoublesPairs.new(@team).pairs.to_h do |p|
      court, = p.usual_court
      [ p.players.map(&:id).sort.join("-"), { w: p.wins, l: p.losses, court: court } ]
    end
  end

  SUB_OPTION = "sub".freeze

  # Subs this team has used before (players in its past lineups who aren't on
  # the roster), so a regular sub can be picked again instead of re-typed.
  def load_subs
    member_ids = @members.map(&:id)
    team_lineups = Lineup.joins(:match).where(matches: { tennis_team_id: @team.id }).select(:id)
    @subs = User.where(id: LineupSlot.where(lineup_id: team_lineups).where.not(user_id: nil).select(:user_id))
                .where.not(id: member_ids).order(:name).to_a
  end

  def sub_user_for(name)
    User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
  end

  def ensure_default_slots(lineup)
    needed = @team.lineup_slot_plan
    have = lineup.lineup_slots.group(:line_type, :position).count

    needed.each do |(line_type, position), target_count|
      current_count = have[[ line_type, position ]] || 0
      missing = target_count - current_count
      missing.times do
        LineupSlot.create!(
          lineup:    lineup,
          user:      nil,
          line_type: line_type,
          position:  position
        )
      end
    end
  end
end
