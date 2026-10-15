# Friendlies: a social round robin. The organizer books it and shares one
# link; anyone adds their name (no account, no limit). Courts are worked out
# from the names (4 per court) and the organizer generates fair doubles
# lineups for up to 3 sets. Booking needs an account; the share page and
# adding your name don't.
class FriendliesController < ApplicationController
  GUEST_COOKIE = :friendly_guest_keys

  before_action :require_login, only: [ :index, :new, :create, :edit, :update, :destroy,
                                        :add_player, :toggle_spot, :generate, :swap, :set_done ]
  before_action :load_friendly, except: [ :index, :new, :create ]
  before_action :require_organizer, only: [ :edit, :update, :destroy, :add_player, :toggle_spot,
                                            :generate, :swap, :set_done ]

  # GET /friendlies — every friendly I organized or joined, newest first.
  def index
    @friendlies = Friendly.involving(current_user).includes(:spots).order(starts_at: :desc)
  end

  # GET /friendlies/new
  def new
    @friendly = Friendly.new(starts_at: Time.current.change(min: 0) + 1.day)
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
    params.require(:friendly).permit(:title, :starts_at, :location, :sets_count, :notes)
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
