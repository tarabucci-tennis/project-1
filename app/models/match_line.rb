class MatchLine < ApplicationRecord
  belongs_to :entered_by, class_name: "User", optional: true
  belongs_to :match
  has_many :match_line_players, dependent: :destroy
  has_many :players, through: :match_line_players, source: :user

  validates :line_type, presence: true, inclusion: { in: %w[singles doubles] }
  validates :position, presence: true

  def won?
    result == "win"
  end

  def lost?
    result == "loss"
  end

  def score_display
    sets = [ set1_score, set2_score, set3_score ].compact.reject(&:blank?)
    sets.join(", ")
  end

  # Per-set game breakdown, parsed from the "ours-theirs" set strings
  # (e.g. "2-6" → our pair 2, their pair 6). Returns one entry per set
  # that was actually played: [{ ours: "2", theirs: "6" }, ...].
  def set_games
    [ set1_score, set2_score, set3_score ].filter_map do |s|
      next if s.blank?
      ours, theirs = s.to_s.split("-", 2).map { |n| n.to_s.strip }
      { ours: ours.presence || "–", theirs: theirs.presence || "–" }
    end
  end

  def our_games
    set_games.map { |g| g[:ours] }
  end

  def their_games
    set_games.map { |g| g[:theirs] }
  end

  # Total games for each side, across every set played (numbers only).
  def games_total
    set_games.each_with_object([ 0, 0 ]) do |g, t|
      t[0] += g[:ours].to_i if g[:ours].to_s.match?(/\A\d+\z/)
      t[1] += g[:theirs].to_i if g[:theirs].to_s.match?(/\A\d+\z/)
    end
  end

  # Sets won by each side.
  def sets_total
    set_games.each_with_object([ 0, 0 ]) do |g, t|
      o, th = g[:ours].to_i, g[:theirs].to_i
      t[0] += 1 if o > th
      t[1] += 1 if th > o
    end
  end

  def scored?
    set_games.any? || result.present?
  end

  # Names of our players on this line (app users).
  def our_player_names
    match_line_players.map { |mlp| mlp.user&.name }.compact.reject(&:blank?)
  end

  # Opponent player names, parsed from the free-text "opponents" field
  # (captains type "Jane Smith / Mary Jones").
  def opponent_names
    opponents.to_s.split(%r{\s*/\s*}).map(&:strip).reject(&:blank?)
  end

  def line_label
    if line_type == "singles"
      "Singles #{display_position}"
    elsif (level = tri_level)
      "#{level} Doubles"
    else
      "Doubles #{display_position}"
    end
  end

  # "1S" / "1D" / "2D" — matches the lineup preview style on team pages.
  # Tri-Level lines read as their level ("4.5").
  def short_label
    tri_level || "#{display_position}#{line_type == 'singles' ? 'S' : 'D'}"
  end

  # On a Tri-Level team, this doubles line's level ("4.5"); otherwise nil.
  def tri_level
    return nil unless line_type == "doubles"
    match&.tennis_team&.doubles_line_level(display_position)
  end

  private

  # USTA matches store doubles at positions 2-5 because singles
  # takes position 1 and the unique index is [match_id, position].
  # For display we want "Doubles 1" to "Doubles 4", so subtract the
  # number of singles lines. Inter-Club / Del-Tri have no singles,
  # so the offset is 0 and positions render 1:1.
  def display_position
    return position if line_type == "singles"
    singles_offset = match.match_lines.where(line_type: "singles").count
    pos = position - singles_offset
    pos < 1 ? position : pos
  end
end
