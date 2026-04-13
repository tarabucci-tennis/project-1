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
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains can set lineups."
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
  end

  # PATCH /teams/:team_id/matches/:match_id/lineup — captain saves lineup
  def update
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains can set lineups."
    end

    @lineup = @match.lineup || @match.create_lineup!

    # Make sure all 9 slots exist before we try to update them
    ensure_default_slots(@lineup)

    ActiveRecord::Base.transaction do
      if params[:slots].present?
        params[:slots].each do |slot_id, slot_data|
          slot = @lineup.lineup_slots.find(slot_id)
          update_attrs = {}

          new_user_id = slot_data[:user_id].presence
          if new_user_id && slot.user_id.to_s != new_user_id.to_s
            update_attrs[:user_id] = new_user_id
          end

          # Captain override: "Already confirmed" checkbox
          if slot_data.key?(:confirmed)
            if slot_data[:confirmed] == "1"
              update_attrs[:confirmation] = "confirmed"
              update_attrs[:confirmed_at] = Time.current
            else
              # Unchecked — reset to pending so the player still gets emailed
              update_attrs[:confirmation] = "pending"
              update_attrs[:confirmed_at] = nil
            end
          end

          slot.update!(update_attrs) if update_attrs.any?
        end
      end

      # Publish if requested
      if params[:publish] == "true" && !@lineup.published?
        @lineup.update!(published: true, published_at: Time.current)

        # Only email players who are NOT already confirmed by the captain
        # AND have a real user assigned. If the captain checked "Already
        # confirmed" for a slot, we skip the email — the captain already
        # got a verbal yes via text / in person. Unfilled slots (user_id
        # is nil) are also skipped.
        @lineup.lineup_slots.includes(:user).where(confirmation: "pending").each do |slot|
          next if slot.user.nil?
          next unless slot.user.email.present?
          LineupMailer.lineup_posted(slot).deliver_later
        end
      end
    end

    redirect_to team_path(@team), notice: @lineup.published? ? "Lineup sent to team!" : "Lineup saved (not sent yet)."
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

  def set_team_and_match
    @team = TennisTeam.find(params[:team_id])
    @match = @team.matches.find(params[:match_id])
  end

  def require_login
    redirect_to login_path unless current_user
  end

  # Top up the lineup so it has the canonical USTA 40+ structure:
  #   1 singles slot at position 1
  #   2 doubles slots at positions 1, 2, 3, 4 (total 8 doubles slots)
  #   = 9 slots total
  #
  # Idempotent: counts how many slots exist for each (line_type, position)
  # pair and creates whatever is missing. New slots are created with
  # user_id=NULL — the captain fills them in by picking players from the
  # dropdowns on the edit form. This avoids the unique-index clash that
  # a shared placeholder user would cause on the doubles positions.
  def ensure_default_slots(lineup)
    needed = {
      [ "singles", 1 ] => 1,
      [ "doubles", 1 ] => 2,
      [ "doubles", 2 ] => 2,
      [ "doubles", 3 ] => 2,
      [ "doubles", 4 ] => 2
    }

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
