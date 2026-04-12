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

    @lineup = @match.lineup || @match.build_lineup
    @members = @team.members.order(:name)

    # Build default slots if none exist
    if @lineup.lineup_slots.empty? && @lineup.persisted?
      build_default_slots(@lineup)
    end

    @slots = @lineup.lineup_slots.includes(:user).order(position: :asc)
  end

  # PATCH /teams/:team_id/matches/:match_id/lineup — captain saves lineup
  def update
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains can set lineups."
    end

    @lineup = @match.lineup || @match.create_lineup!

    # Build default slots if first time
    build_default_slots(@lineup) if @lineup.lineup_slots.empty?

    ActiveRecord::Base.transaction do
      if params[:slots].present?
        params[:slots].each do |slot_id, slot_data|
          slot = @lineup.lineup_slots.find(slot_id)
          new_user_id = slot_data[:user_id].presence
          if new_user_id
            slot.update!(user_id: new_user_id, confirmation: "pending", confirmed_at: nil)
          end
        end
      end

      # Publish if requested
      if params[:publish] == "true" && !@lineup.published?
        @lineup.update!(published: true, published_at: Time.current)

        # Email each player in the lineup who has an email
        @lineup.lineup_slots.includes(:user).each do |slot|
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

  def build_default_slots(lineup)
    # USTA format: 1S + 4D = 5 lines, but singles has 1 player, doubles has 2
    # We create one slot per PLAYER position (not per line)
    # 1S = 1 slot, 1D = 2 slots, 2D = 2 slots, 3D = 2 slots, 4D = 2 slots = 9 slots total
    placeholder = @team.members.first

    LineupSlot.create!(lineup: lineup, user: placeholder, line_type: "singles", position: 1)
    (1..4).each do |d|
      2.times do
        LineupSlot.create!(lineup: lineup, user: placeholder, line_type: "doubles", position: d)
      end
    end
  end
end
