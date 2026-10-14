# Friendlies: book a casual match, share one link, players claim spots first
# come first served (4 per court, then a waitlist). The share page and
# claiming work without an account; booking needs one.
class FriendliesController < ApplicationController
  GUEST_COOKIE = :friendly_guest_keys

  before_action :require_login, only: [ :new, :create, :destroy ]
  before_action :load_friendly, only: [ :show, :claim, :unclaim, :destroy ]

  # GET /friendlies/new
  def new
    @friendly = Friendly.new(courts: 1, starts_at: Time.current.change(min: 0) + 1.day)
  end

  # POST /friendlies
  def create
    @friendly = current_user.organized_friendlies.new(friendly_params)
    if @friendly.save
      @friendly.spots.create!(user: current_user, name: current_user.name) if params[:im_playing] == "1"
      redirect_to friendly_path(@friendly), notice: "Friendly booked! Share the link so people can claim a spot."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /f/:token
  def show
    @my_spot = my_spot
  end

  # POST /f/:token/claim
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
      place = @friendly.reload.spots.index(spot).to_i
      msg = place < @friendly.capacity ? "You're in! ✓" : "It's full, so you're on the waitlist (##{place - @friendly.capacity + 1})."
      redirect_to friendly_path(@friendly), notice: msg
    else
      redirect_to friendly_path(@friendly), alert: spot.errors.full_messages.to_sentence
    end
  end

  # DELETE /f/:token/claim?spot_id=
  def unclaim
    spot = @friendly.spots.find_by(id: params[:spot_id])
    return redirect_to(friendly_path(@friendly), alert: "That spot is already gone.") unless spot
    return redirect_to(friendly_path(@friendly), alert: "You can only remove your own name.") unless can_remove?(spot)

    spot.destroy
    redirect_to friendly_path(@friendly), notice: "#{spot.name} is off the list."
  end

  # DELETE /f/:token
  def destroy
    unless organizer?
      return redirect_to(friendly_path(@friendly), alert: "Only the organizer can cancel this friendly.")
    end
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
    params.require(:friendly).permit(:title, :starts_at, :location, :courts, :notes)
  end

  def organizer?
    current_user && @friendly.organizer_id == current_user.id
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
