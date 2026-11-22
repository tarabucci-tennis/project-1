# Data update (Tara, Nov 17 2026):
# 1. "Kriste Davidse" and "Kristen Davidse" are definitely one person. The
#    Nov 16 update skipped them (both could sign in, or there were more than
#    two records). Merge every Davidse record matching those spellings into
#    one "Kristen Davidse". If more than one can sign in, the login she used
#    most recently is kept and the others' emails are cleared first (same
#    person, so nobody real loses access).
# 2. Sarah Dougherty's USTA rating date: 12/31/2025 (her year-end rating),
#    only if it's still blank.
# 3. Tri Hards: archived (season over), if it isn't already.
# Safe to run again.
class TaraConfirmedFixesNov17 < ActiveRecord::Migration[8.1]
  def up
    keys = [ "Kristen Davidse", "Kriste Davidse" ].map { |n| DuplicatePeople.key(n) }
    people = User.where.not(name: [ nil, "" ]).select { |u| keys.include?(DuplicatePeople.key(u.name)) }
    if people.size >= 2
      with_login = people.select { |u| u.email.present? }
      if with_login.size > 1
        keep = with_login.max_by { |u| [ u.last_sign_in_at || u.last_seen_at || Time.at(0), u.sign_in_count.to_i ] }
        (with_login - [ keep ]).each do |u|
          say "Davidse ##{u.id}: clearing unused sign-in #{u.email} (kept ##{keep.id})"
          u.update_columns(email: nil, password_digest: nil)
        end
      end
      survivor = nil
      people.map(&:reload).sort_by { |u| u.email.present? ? 0 : 1 }.each do |u|
        if survivor.nil?
          survivor = u
          next
        end
        survivor = UserMerge.new(survivor, u, name: [ survivor.name, u.name ].find { |n| n.squish == "Kristen Davidse" } || survivor.name).call.survivor
      end
      survivor.update_columns(name: "Kristen Davidse")
      say "Davidse: merged #{people.size} records into ##{survivor.id} Kristen Davidse"
    else
      say "Davidse: found #{people.size} record(s), nothing to merge"
    end

    sarah = User.where("LOWER(name) = ?", "sarah dougherty").to_a
    if sarah.size == 1 && sarah.first.ntrp_rating_date.blank?
      sarah.first.update_columns(ntrp_rating_date: Date.new(2025, 12, 31))
      say "Sarah Dougherty: rating date set to 12/31/2025"
    end

    TennisTeam.where("LOWER(name) = ?", "tri hards").where(archived: false).find_each do |t|
      t.update_columns(archived: true)
      say "Tri Hards ##{t.id}: archived"
    end
  end

  def down
    # Merges and these fixes aren't undone.
  end
end
