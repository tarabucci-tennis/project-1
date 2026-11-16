# Data update (Tara, Nov 16 2026, Priority 2 item 9): merge the three people
# Tara confirmed have two records each, and fill Kiss My Ace Winter's missing
# season details from what she gave us (11/2/2026 start, Bryn Mawr Racquet
# Club). Uses UserMerge, the same code as Admin > Possible duplicates.
#
# Safe to run again: a pair is merged only when exactly two records match
# its spellings (after a merge there's one, so it's skipped), and never when
# both records can sign in (UserMerge refuses). Only blank team fields are
# filled.
class MergeKnownDuplicatePeople < ActiveRecord::Migration[8.1]
  PAIRS = [
    { names: [ "JoAnne Steinberg", "Joanne Steinberg" ], keep: "JoAnne Steinberg" },
    { names: [ "Sarah Dougherty" ], keep: "Sarah Dougherty" },
    # Keep the spelling on the record that can sign in (she typed it herself).
    { names: [ "Kristen Davidse", "Kriste Davidse" ], keep: nil }
  ].freeze

  def up
    PAIRS.each do |pair|
      keys = pair[:names].map { |n| DuplicatePeople.key(n) }
      people = User.where.not(name: [ nil, "" ]).select { |u| keys.include?(DuplicatePeople.key(u.name)) }
      unless people.size == 2
        say "#{pair[:names].first}: found #{people.size} record(s), not 2 — skipped"
        next
      end
      keep, = UserMerge.order(*people)
      name = pair[:keep] || keep.name
      result = UserMerge.new(people[0], people[1], name: name).call
      say "Merged #{pair[:names].join(' / ')} into ##{result.survivor.id} #{result.survivor.name}"
    rescue UserMerge::Refused => e
      say "#{pair[:names].first}: not merged — #{e.message}"
    end

    team = TennisTeam.where("LOWER(name) = ?", "kiss my ace winter").first
    if team
      team.season_name = "Winter 2026-27" if team.season_name.blank?
      team.start_date  = Date.new(2026, 11, 2) if team.start_date.blank?
      team.home_court  = "Bryn Mawr Racquet Club" if team.home_court.blank?
      team.save!(validate: false)
      say "Kiss My Ace Winter: season details filled where blank"
    end
  end

  def down
    # Merges can't be split back apart.
  end
end
