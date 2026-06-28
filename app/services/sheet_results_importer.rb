# Imports match results (and the matching posted lineup) from parsed
# spreadsheet rows into an existing team's schedule.
#
# Each row represents one line of one match, with the columns Tara keeps in
# her Google Sheet:
#   match_date, opponent, line ("Singles" / "#1 Doubles" ...),
#   player_1, player_2, opponent_1, opponent_2, score ("6-1 1-6 1-0"), result ("W"/"L")
#
# For every match that has at least one scored line it will, idempotently:
#   * fill in each line's set scores, win/loss, opponents, and players,
#   * set the match's overall result + "won-lost" score summary,
#   * build and PUBLISH the lineup from the same players, so a match can
#     never show a score without also showing who played (Tara's request).
#
# Re-running with updated rows simply re-syncs; it does not duplicate.
class SheetResultsImporter
  Outcome = Struct.new(:matches_updated, :lines_updated, :lineups_posted, :unmatched, keyword_init: true) do
    def to_s
      msg = "#{matches_updated} match(es), #{lines_updated} line(s), #{lineups_posted} lineup(s) posted"
      msg += " — UNMATCHED: #{unmatched.join('; ')}" if unmatched.any?
      msg
    end
  end

  def initialize(team)
    @team = team
    @members_by_name = team.members.index_by { |u| normalize(u.name) }
  end

  # rows: Array of Hashes (symbol keys). Returns an Outcome.
  def import(rows)
    outcome = Outcome.new(matches_updated: 0, lines_updated: 0, lineups_posted: 0, unmatched: [])

    rows.group_by { |r| [ to_date(r[:match_date]), normalize(r[:opponent]) ] }.each do |(date, opp_key), group|
      scored = group.select { |r| scored?(r) }
      next if scored.empty?

      match = find_match(date, opp_key)
      unless match
        outcome.unmatched << "#{date} vs #{group.first[:opponent]}"
        next
      end

      ActiveRecord::Base.transaction { import_match(match, scored, outcome) }
      outcome.matches_updated += 1
    end

    outcome
  end

  private

  def import_match(match, rows, outcome)
    lineup = match.lineup || match.create_lineup!
    lineup.lineup_slots.destroy_all

    rows.each do |row|
      line_type, dbl_index = parse_line(row[:line])
      next unless line_type

      line = match.match_lines.find_or_initialize_by(position: match_line_position(line_type, dbl_index))
      set1, set2, set3 = split_sets(row[:score])
      line.assign_attributes(
        line_type:  line_type,
        result:     normalize_result(row[:result]),
        set1_score: set1, set2_score: set2, set3_score: set3,
        opponents:  join_names(row[:opponent_1], row[:opponent_2])
      )
      line.save!

      slot_position = (line_type == "singles") ? 1 : dbl_index
      line.match_line_players.destroy_all
      [ row[:player_1], row[:player_2] ].each do |pname|
        user = resolve_user(pname)
        next unless user
        line.match_line_players.find_or_create_by!(user: user)
        unless lineup.lineup_slots.exists?(user_id: user.id)
          lineup.lineup_slots.create!(line_type: line_type, position: slot_position, user: user, confirmation: "confirmed")
        end
      end

      outcome.lines_updated += 1
    end

    won  = match.match_lines.where(result: "win").count
    lost = match.match_lines.where(result: "loss").count
    match.update!(result: (won > lost ? "win" : "loss"), score_summary: "#{won}-#{lost}")

    lineup.update!(published: true, published_at: Time.current)
    outcome.lineups_posted += 1
  end

  def find_match(date, opp_key)
    @team.matches.detect { |m| m.match_date.to_date == date && normalize(m.opponent) == opp_key }
  end

  # "Singles" => ["singles", nil]; "#1 Doubles" / "#1" => ["doubles", 1]
  def parse_line(label)
    s = label.to_s.strip
    return [ "singles", nil ] if s.match?(/singles/i)
    return [ "doubles", Regexp.last_match(1).to_i ] if s.match(/#?\s*(\d+)/)
    nil
  end

  # match_lines use a unique [match_id, position] index: singles takes
  # position 1, so USTA doubles live at 2..5. Leagues with no singles
  # (Inter-Club / Local) put doubles at 1..6.
  def match_line_position(line_type, dbl_index)
    return 1 if line_type == "singles"
    @team.has_singles_line? ? dbl_index + 1 : dbl_index
  end

  def split_sets(score)
    parts = score.to_s.strip.split(/\s+/).reject(&:blank?)
    [ parts[0], parts[1], parts[2] ]
  end

  def normalize_result(result)
    case result.to_s.strip.upcase
    when "W" then "win"
    when "L" then "loss"
    end
  end

  def scored?(row)
    row[:score].to_s.strip.present? || %w[W L].include?(row[:result].to_s.strip.upcase)
  end

  def join_names(*names)
    names.map { |n| n.to_s.strip }.reject(&:blank?).join(" / ").presence
  end

  def resolve_user(name)
    return nil if name.to_s.strip.blank?
    @members_by_name[normalize(name)] ||
      User.where("LOWER(name) = ?", name.strip.downcase).first ||
      User.create!(name: name.strip)
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def to_date(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end
end
