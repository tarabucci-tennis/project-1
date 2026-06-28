# Imports a user's personal Del-Tri match history (from their player.php page)
# into player_matches, so their results show on their profile without anyone
# having to create a team. Idempotent: re-running re-syncs and prunes matches
# that disappeared from the source.
#
# Usage: DeltriPlayerImport.new(user).call  (no-op if the user has no link)
class DeltriPlayerImport
  SOURCE = "deltri".freeze

  Result = Struct.new(:imported, :notes, keyword_init: true) do
    def to_s
      (imported.map { |name, n| "#{name}: #{n} matches" } + notes).join(" · ")
    end
  end

  def self.sync_all
    imported = {}
    notes = []
    User.where.not(deltri_player_url: [ nil, "" ]).find_each do |user|
      r = new(user).call
      imported.merge!(r.imported)
      notes.concat(r.notes)
    end
    Result.new(imported: imported, notes: notes)
  end

  def initialize(user)
    @user = user
  end

  def call
    return Result.new(imported: {}, notes: []) if @user.deltri_player_url.blank?

    rows = DeltriPlayerHistory.new(@user.deltri_player_url).call
    seen = []
    rows.each do |row|
      next if row[:source_key].blank?
      pm = @user.player_matches.find_or_initialize_by(source: SOURCE, source_key: row[:source_key])
      pm.assign_attributes(
        league: "Del-Tri",
        division: row[:division], date_label: row[:date_label], played_on: row[:played_on],
        match_label: row[:match_label], line_label: row[:line_label],
        partner: row[:partner], opponents: row[:opponents],
        score: row[:score], result: row[:result]
      )
      pm.save!
      seen << pm.id
    end
    @user.player_matches.where(source: SOURCE).where.not(id: seen).delete_all if seen.any?

    Result.new(imported: { @user.name => rows.size }, notes: [])
  rescue StandardError => e
    Result.new(imported: {}, notes: [ "#{@user.name}: #{e.class} — #{e.message}" ])
  end
end
