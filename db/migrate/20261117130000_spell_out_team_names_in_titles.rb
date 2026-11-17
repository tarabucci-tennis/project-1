# Data update (Tara, Nov 17 2026, Priority 3 item 16): one spelling everywhere.
# Titles people typed on calendar entries, friendlies and matches said
# "Over-served" and "KMA" while the teams are "Over Served" and "Kiss My Ace".
# Rewrites only those words; everything else in the text stays as typed.
# Safe to run again (already-fixed text doesn't match).
class SpellOutTeamNamesInTitles < ActiveRecord::Migration[8.1]
  FIXES = [
    [ /\bover[\s-]?served\b/i, "Over Served" ],
    [ /\bKMA\b/, "Kiss My Ace" ]
  ].freeze

  COLUMNS = {
    "friendlies" => %w[title],
    "team_events" => %w[title notes],
    "matches" => %w[opponent notes]
  }.freeze

  def up
    COLUMNS.each do |table, columns|
      columns.each do |col|
        rows = select_rows("SELECT id, #{col} FROM #{table} WHERE #{col} IS NOT NULL")
        rows.each do |id, text|
          fixed = FIXES.reduce(text.to_s) { |t, (pattern, word)| t.gsub(pattern, word) }
          next if fixed == text
          execute "UPDATE #{table} SET #{col} = #{connection.quote(fixed)} WHERE id = #{id.to_i}"
          say "#{table} ##{id} #{col}: #{text.inspect} -> #{fixed.inspect}"
        end
      end
    end
  end

  def down
    # Spelling fixes aren't undone.
  end
end
