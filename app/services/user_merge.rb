# Merges two Court Report person records that are the same human (e.g.
# "Joanne Steinberg" and "JoAnne Steinberg") into one. Admin-only, from
# Admin > Possible duplicates.
#
# The record that can sign in (has an email) survives, so nobody loses their
# login; everything that points at the other record (team spots, line scores,
# lineups, availability, subs, league-site history, friendlies, ...) moves to
# it, and the other record is deleted. Where both records have the same thing
# (both on the same team, both on the same line), the survivor's copy is kept
# and the duplicate's is dropped. The admin picks which spelling of the name
# to keep. Runs in one transaction: all or nothing.
class UserMerge
  class Refused < StandardError; end

  Result = Struct.new(:survivor, :moved, keyword_init: true)

  # Survivor first: the one with a login; otherwise the one with more data.
  def self.order(a, b)
    return [ a, b ] if a.email.present? && b.email.blank?
    return [ b, a ] if b.email.present? && a.email.blank?
    weight = ->(u) { u.match_line_players.count + u.team_memberships.count + u.player_matches.count }
    weight.call(a) >= weight.call(b) ? [ a, b ] : [ b, a ]
  end

  def initialize(a, b, name:)
    raise Refused, "Pick two different people." if a.nil? || b.nil? || a.id == b.id
    if a.email.present? && b.email.present?
      raise Refused, "Both have their own sign-in (#{a.email}, #{b.email}). Merging would lock one of them out — " \
                     "remove the email from the one that isn't used (Site members → Edit) and merge again."
    end
    @keep, @drop = self.class.order(a, b)
    @name = name.to_s.squish.presence || @keep.name
    raise Refused, "Keep one of the two names." unless [ a.name, b.name ].map { |n| n.to_s.squish }.include?(@name)
  end

  def call
    moved = Hash.new(0)
    ApplicationRecord.transaction do
      move_unique(TeamMembership, :tennis_team_id, moved, scope: ->(r) { r.archived_season.blank? ? { archived_season: [ nil, "" ] } : { archived_season: r.archived_season } }) do |mine, theirs|
        mine.update!(role: "captain") if theirs.role == "captain" && mine.role != "captain"
      end
      move_unique(MatchLinePlayer, :match_line_id, moved)
      move_unique(LineupSlot, :lineup_id, moved)
      move_unique(Availability, :match_id, moved)
      move_unique(TeamSub, :tennis_team_id, moved)
      move_unique(PlayerMatch, :source_key, moved, scope: ->(r) { { source: r.source } })

      if @keep.ical_url.present? && @drop.ical_url.present?
        @drop.external_events.delete_all # the survivor's own calendar resyncs nightly
      else
        moved[:external_events] += ExternalEvent.where(user_id: @drop.id).update_all(user_id: @keep.id)
      end
      moved[:friendly_spots] += FriendlySpot.where(user_id: @drop.id).update_all(user_id: @keep.id)
      moved[:friendlies]     += Friendly.where(organizer_id: @drop.id).update_all(organizer_id: @keep.id)
      moved[:notifications]  += Notification.where(user_id: @drop.id).update_all(user_id: @keep.id)
      Notification.where(actor_id: @drop.id).update_all(actor_id: @keep.id)
      moved[:tennis_stats]   += TennisStat.where(user_id: @drop.id).update_all(user_id: @keep.id)
      moved[:teams_created]  += TennisTeam.where(user_id: @drop.id).update_all(user_id: @keep.id)
      TeamSub.where(added_by_id: @drop.id).update_all(added_by_id: @keep.id)
      UstaLine.where(uploaded_by_id: @drop.id).update_all(uploaded_by_id: @keep.id)

      fill_blanks!
      @drop.reload
      @drop.delete
    end
    Result.new(survivor: @keep.reload, moved: moved)
  end

  private

  # Rows unique per (user, key): move the duplicate's rows unless the
  # survivor already has one for the same key, in which case keep the
  # survivor's (yielding both so the caller can carry something over).
  def move_unique(model, key, moved, scope: ->(_r) { {} })
    model.where(user_id: @drop.id).find_each do |row|
      mine = model.where(user_id: @keep.id, key => row.public_send(key)).where(scope.call(row)).first
      if mine
        yield(mine, row) if block_given?
        row.delete
      else
        row.update_columns(user_id: @keep.id)
        moved[model.model_name.plural.to_sym] += 1
      end
    end
  end

  # The survivor keeps its own values; blanks are filled from the duplicate.
  def fill_blanks!
    attrs = { name: @name }
    %i[email password_digest phone location ntrp_rating ntrp_rating_date tennislink_person_id
       deltri_player_url ical_url dynamic_rating dynamic_rating_date].each do |col|
      attrs[col] = @drop.public_send(col) if @keep.public_send(col).blank? && @drop.public_send(col).present?
    end
    attrs[:admin] = true if @drop.admin?
    attrs[:sign_in_count] = @keep.sign_in_count.to_i + @drop.sign_in_count.to_i
    attrs[:days_visited]  = @keep.days_visited.to_i + @drop.days_visited.to_i
    attrs[:last_seen_at]  = [ @keep.last_seen_at, @drop.last_seen_at ].compact.max
    attrs[:created_at]    = [ @keep.created_at, @drop.created_at ].compact.min
    # The email is unique: free it on the duplicate before the survivor takes it.
    @drop.update_columns(email: nil) if attrs.key?(:email)
    @keep.update_columns(attrs.merge(updated_at: Time.current))
  end
end
