# Friendlies: a social round robin. The organizer books it and shares one
# link; anyone adds their name (no account, no limit). Courts are worked out
# from the names (4 per court) and the organizer generates fair doubles
# lineups for up to 3 sets. Booking needs an account; the share page and
# adding your name don't.
class FriendliesController < ApplicationController
  GUEST_COOKIE = :friendly_guest_keys

  before_action :require_login, only: [ :index, :new, :create, :edit, :update, :destroy, :archive, :archive_all,
                                        :add_player, :toggle_spot, :generate, :swap, :set_done,
                                        :remove_score, :lock_scores ]
  before_action :load_friendly, except: [ :index, :new, :create, :archive_all ]
  before_action :require_organizer, only: [ :edit, :update, :destroy, :archive, :add_player, :toggle_spot,
                                            :generate, :swap, :set_done, :remove_score, :lock_scores ]

  # GET /friendlies — every friendly I organized or joined, newest first.
  def index
    @friendlies = Friendly.involving(current_user).unarchived.includes(:spots, :scores).order(starts_at: :desc)
    @archived_friendlies = Friendly.involving(current_user).archived.order(starts_at: :desc).to_a
    @archivable_count = current_user.organized_friendlies.unarchived.count
  end

  # PATCH /f/:token/archive — archive or restore one friendly (organizer only).
  # Archived friendlies leave every list but nothing is deleted.
  def archive
    restoring = @friendly.archived?
    @friendly.update!(archived_at: restoring ? nil : Time.current)
    redirect_to friendlies_path, notice: restoring ? "#{@friendly.title} restored." : "#{@friendly.title} archived. Restore it any time from Archived friendlies."
  end

  # PATCH /friendlies/archive_all — archive every friendly I booked.
  def archive_all
    count = current_user.organized_friendlies.unarchived.update_all(archived_at: Time.current, updated_at: Time.current)
    redirect_to friendlies_path, notice: "#{count} #{'friendly'.pluralize(count)} archived. Restore any of them from Archived friendlies."
  end

  # GET /friendlies/new
  def new
    starts_at = Time.current.change(min: 0) + 1.day
    @friendly = Friendly.new(starts_at: starts_at, ends_at: starts_at + 90.minutes)
  end

  # POST /friendlies
  def create
    @friendly = current_user.organized_friendlies.new(friendly_params)
    if @friendly.save
      @friendly.spots.create!(user: current_user, name: current_user.name) if params[:im_playing] == "1"
      redirect_to friendly_path(@friendly), notice: "Friendly booked! Share the link so people can add their names."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /f/:token
  def show
    # Catch up a lineup whose names changed before subs were swapped in automatically.
    @friendly.sync_lineup_names! if @friendly.lineup_out_of_date?
    @my_spot = my_spot
    @suggest_names = organizer? ? teammate_names : []
  end

  # GET /f/:token/edit
  def edit
  end

  # PATCH /f/:token
  def update
    if @friendly.update(friendly_params)
      redirect_to friendly_path(@friendly), notice: "Friendly updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /f/:token/claim — add my own name.
  def claim
    if my_spot
      return redirect_to(friendly_path(@friendly), notice: "You're already on the list.")
    end

    spot = @friendly.spots.new
    if current_user
      spot.user = current_user
      spot.name = current_user.name
    else
      spot.name = params[:name].to_s.squish
      spot.guest_key = SecureRandom.hex(12)
    end

    if spot.save
      remember_guest(spot.guest_key) if spot.guest_key
      redirect_to friendly_path(@friendly), notice: claim_message(spot)
    else
      redirect_to friendly_path(@friendly), alert: spot.errors.full_messages.to_sentence
    end
  end

  # DELETE /f/:token/claim?spot_id=
  def unclaim
    spot = @friendly.spots.find_by(id: params[:spot_id])
    return redirect_to(friendly_path(@friendly), alert: "That name is already gone.") unless spot
    return redirect_to(friendly_path(@friendly), alert: "You can only remove your own name.") unless can_remove?(spot)

    spot.destroy
    redirect_to friendly_path(@friendly), notice: "#{spot.name} is off the list."
  end

  # POST /f/:token/players — organizer adds someone by name (late arrival,
  # or someone who won't use the link).
  def add_player
    spot = @friendly.spots.new(name: params[:name].to_s.squish)
    if spot.save
      redirect_to friendly_path(@friendly, anchor: "lineup"), notice: "#{spot.name} added."
    else
      redirect_to friendly_path(@friendly, anchor: "lineup"), alert: spot.errors.full_messages.to_sentence
    end
  end

  # PATCH /f/:token/spots/:spot_id/toggle — in or out of today's rotation.
  def toggle_spot
    spot = @friendly.spots.find_by(id: params[:spot_id])
    spot&.update!(in_lineup: !spot.in_lineup)
    redirect_to friendly_path(@friendly, anchor: "lineup")
  end

  # POST /f/:token/lineup — (re)generate every set not marked played.
  def generate
    unless @friendly.can_generate?
      return redirect_to(friendly_path(@friendly, anchor: "lineup"),
                         alert: "You need at least #{Friendly::MIN_PLAYERS} players to make a lineup.")
    end
    kept = @friendly.lineup_sets.count { |s| s["done"] }
    @friendly.generate_lineup!
    redirect_to friendly_path(@friendly, anchor: "lineup"),
                notice: kept.positive? ? "New lineup for the sets not played yet." : "Lineup ready."
  end

  # PATCH /f/:token/lineup/swap?set=&a=&b=
  def swap
    ok = @friendly.swap_players!(params[:set], params[:a], params[:b])
    redirect_to friendly_path(@friendly, anchor: "set-#{params[:set].to_i + 1}"),
                **(ok ? { notice: "Swapped." } : { alert: "Couldn't swap those two." })
  end

  # PATCH /f/:token/lineup/sets/:set/courts/:court/score — optional games for
  # each pair. Anyone with the link can add one, like adding a name.
  def score
    ok = @friendly.set_court_score!(params[:set], params[:court], params[:a], params[:b])
    redirect_to friendly_path(@friendly, anchor: "set-#{params[:set].to_i + 1}"),
                **(ok ? { notice: "Score saved." } : { alert: "Scores must be whole numbers (or leave both blank)." })
  end

  SCORER_COOKIE = :friendly_scorer_name

  # POST /f/:token/scores — anyone with the link, no sign-in. Saving a court
  # that already has a score updates it; every save is logged with the name.
  def save_score
    anchor = { anchor: "scores" }
    return redirect_to(friendly_path(@friendly, **anchor), alert: "Scores are locked. Ask the organizer to unlock them.") if @friendly.scores_locked?

    sp = params.fetch(:score, {}).permit(:court, :pair_a, :pair_b, :entered_by, *(1..FriendlyScore::MAX_SETS).flat_map { |i| [ "set#{i}_a", "set#{i}_b" ] })
    score = @friendly.scores.find_or_initialize_by(court: sp[:court].to_i)
    name = sp[:entered_by].to_s.strip.first(60)
    score.assign_attributes(pair_a: sp[:pair_a].to_s.strip.presence, pair_b: sp[:pair_b].to_s.strip.presence, entered_by: name)
    score.assign_set_boxes(sp)
    score.record_change!(name) if name.present?
    if score.save
      cookies.permanent[SCORER_COOKIE] = name
      redirect_to friendly_path(@friendly, **anchor), notice: "Court #{score.court} score saved."
    else
      redirect_to friendly_path(@friendly, **anchor), alert: score.errors.full_messages.to_sentence
    end
  end

  # DELETE /f/:token/scores/:court — organizer only.
  def remove_score
    @friendly.scores.where(court: params[:court].to_i).destroy_all
    redirect_to friendly_path(@friendly, anchor: "scores"), notice: "Score removed."
  end

  # PATCH /f/:token/scores/lock — organizer only; toggles.
  def lock_scores
    @friendly.update!(scores_locked_at: @friendly.scores_locked? ? nil : Time.current)
    redirect_to friendly_path(@friendly, anchor: "scores"),
                notice: @friendly.scores_locked? ? "Scores locked. Nobody can change them now." : "Scores unlocked."
  end

  def scorer_name
    cookies[SCORER_COOKIE].presence || current_user&.name
  end
  helper_method :scorer_name

  # PATCH /f/:token/lineup/sets/:set/done?done=1|0
  def set_done
    @friendly.mark_set_done!(params[:set], params[:done] == "1")
    redirect_to friendly_path(@friendly, anchor: "set-#{params[:set].to_i + 1}")
  end

  # DELETE /f/:token
  def destroy
    @friendly.destroy
    redirect_to teams_path, notice: "Friendly cancelled."
  end

  helper_method :organizer?, :can_remove?

  private

  def load_friendly
    @friendly = Friendly.includes(spots: :user).find_by(token: params[:token])
    redirect_to(root_path, alert: "That friendly link isn't valid anymore.") unless @friendly
  end

  def friendly_params
    params.require(:friendly).permit(:title, :starts_at, :start_date, :start_time, :duration, :end_time, :location, :sets_count, :notes)
  end

  def organizer?
    current_user && (@friendly.organizer_id == current_user.id || current_user.admin?)
  end

  def require_organizer
    redirect_to(friendly_path(@friendly), alert: "Only the organizer can do that.") unless organizer?
  end

  def claim_message(spot)
    @friendly.reload
    place = @friendly.waitlist.index(spot)
    return "You're in! ✓" unless place
    more = @friendly.players_for_next_court
    "You're on the waitlist (##{place + 1}). #{more} more #{more == 1 ? 'person makes' : 'people make'} #{@friendly.courts_needed.zero? ? 'the first' : 'another'} court."
  end

  # Names from the organizer's teams, suggested when they add a player.
  def teammate_names
    User.joins(:team_memberships).merge(TeamMembership.active)
        .where(team_memberships: { tennis_team_id: current_user.member_teams.pluck(:id) })
        .distinct.order(:name).limit(400).pluck(:name)
  end

  def guest_keys
    Array(cookies.signed[GUEST_COOKIE])
  end

  def remember_guest(key)
    cookies.signed.permanent[GUEST_COOKIE] = (guest_keys + [ key ]).last(50)
  end

  def my_spot
    @friendly.spot_for(current_user) ||
      @friendly.spots.detect { |s| s.guest_key.present? && guest_keys.include?(s.guest_key) }
  end

  def can_remove?(spot)
    organizer? ||
      (current_user && spot.user_id == current_user.id) ||
      (spot.guest_key.present? && guest_keys.include?(spot.guest_key))
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
