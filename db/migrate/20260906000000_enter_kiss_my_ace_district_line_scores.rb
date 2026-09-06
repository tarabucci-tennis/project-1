# Enters the line-by-line scores for Kiss My Ace's four 2026 District matches,
# read from TennisRecord's public scorecards and reconciled to each match's
# court score. Also corrects each match's overall result/score from the line
# tally (TennisRecord's district schedule listed the winner first, so a lost
# match could import with the score reversed — DVTA Slice was really a 2-3
# loss, not a 3-2 win).
#
# Idempotent: sets the match result every run, but only creates lines for a
# match that has none yet, so re-running never duplicates.
class EnterKissMyAceDistrictLineScores < ActiveRecord::Migration[8.1]
  # opponent => { result:, score:, lines: [ {label, type, pos, players, opp, s1, s2, s3, result} ] }
  MATCHES = {
    "Snider" => {
      result: "win", score: "5-0",
      lines: [
        { type: "singles", pos: 1, players: [ "Jaclyn Groenen" ], opp: "",                               s1: "6-0", s2: "6-0", s3: nil,  result: "win" },
        { type: "doubles", pos: 2, players: [ "Vanessa Halloran", "Sarah Brautigan" ], opp: "Alanna Wildgrube / Kim Webster", s1: "6-3", s2: "6-3", s3: nil, result: "win" },
        { type: "doubles", pos: 3, players: [ "Alison Vachris", "Tara Bucci" ],       opp: "Sally Finley / Molly Mahn",       s1: "6-0", s2: "6-3", s3: nil, result: "win" },
        { type: "doubles", pos: 4, players: [ "Doris Kerr", "Lynn Sundblad" ],        opp: "Andrea Mangan / Lynn Johnston",   s1: "2-6", s2: "7-6", s3: "1-0", result: "win" },
        { type: "doubles", pos: 5, players: [ "Mary Marshall", "Nicole Costelloe" ],  opp: "Kari Ries / Lynn Rohrbach",       s1: "4-6", s2: "6-4", s3: "1-0", result: "win" }
      ]
    },
    "Unmatchables" => {
      result: "loss", score: "2-3",
      lines: [
        { type: "singles", pos: 1, players: [ "Jody Staples" ], opp: "Heather Maraldo",                    s1: "6-1", s2: "6-3", s3: nil,  result: "win" },
        { type: "doubles", pos: 2, players: [ "Vanessa Halloran", "Sarah Brautigan" ], opp: "Kathryn Stewart / Lesley Coulson", s1: "0-6", s2: "3-6", s3: nil, result: "loss" },
        { type: "doubles", pos: 3, players: [ "Alison Vachris", "Tara Bucci" ],       opp: "Sara Slattery / Carolyn Carey",   s1: "3-6", s2: "1-6", s3: nil, result: "loss" },
        { type: "doubles", pos: 4, players: [ "Nicole Costelloe", "Jaclyn Groenen" ], opp: "Olivia Andrews / Carol Leslie",   s1: "6-3", s2: "3-6", s3: "0-1", result: "loss" },
        { type: "doubles", pos: 5, players: [ "Lynn Sundblad", "Christina Faidley" ], opp: "Charity Miller / Carly Vettori",  s1: "7-5", s2: "6-0", s3: nil,  result: "win" }
      ]
    },
    "DVTA Slice" => {
      result: "loss", score: "2-3",
      lines: [
        { type: "singles", pos: 1, players: [ "Stephanie Giordano" ], opp: "Michele Gurevich",             s1: "2-6", s2: "3-6", s3: nil,  result: "loss" },
        { type: "doubles", pos: 2, players: [ "Alison Vachris", "Tara Bucci" ],   opp: "Meghann Reddy / Nan Barash",       s1: "3-6", s2: "3-6", s3: nil, result: "loss" },
        { type: "doubles", pos: 3, players: [ "Doris Kerr", "Jaclyn Groenen" ],   opp: "Noelle Frey / Pikai Oh",           s1: "5-7", s2: "5-7", s3: nil, result: "loss" },
        { type: "doubles", pos: 4, players: [ "Helen He", "Rebecca Feinberg" ],   opp: "Debra Lorah / Lynn Selhat",        s1: "6-3", s2: "6-4", s3: nil, result: "win" },
        { type: "doubles", pos: 5, players: [ "Kerry McDuffie", "Nicole Costelloe" ], opp: "Marilyn Blaustein / Angela Pidutti", s1: "3-6", s2: "6-4", s3: "1-0", result: "win" }
      ]
    },
    "Tennis Addiction" => {
      result: "loss", score: "1-4",
      lines: [
        { type: "singles", pos: 1, players: [ "Jaclyn Groenen" ], opp: "Kristen Bria",                     s1: "7-6", s2: "3-6", s3: "1-0", result: "win" },
        { type: "doubles", pos: 2, players: [ "Vanessa Halloran", "Sarah Brautigan" ], opp: "Qianhong Wei / Shannon Milberg", s1: "6-4", s2: "1-6", s3: "0-1", result: "loss" },
        { type: "doubles", pos: 3, players: [ "Alison Vachris", "Tara Bucci" ],       opp: "Jill O'Neill / Stephanie Vo",   s1: "1-6", s2: "6-3", s3: "0-1", result: "loss" },
        { type: "doubles", pos: 4, players: [ "Nicole Costelloe", "Doris Kerr" ],     opp: "Meridith Bebee / Sandy Damico", s1: "2-6", s2: "4-6", s3: nil,  result: "loss" },
        { type: "doubles", pos: 5, players: [ "Helen He", "Rebecca Feinberg" ],       opp: "Dana Cellucci / Kristen Goodman", s1: "3-6", s2: "4-6", s3: nil, result: "loss" }
      ]
    }
  }.freeze

  def up
    team = TennisTeam.where("LOWER(name) = ?", "kiss my ace").first
    return unless team

    MATCHES.each do |opponent, info|
      match = team.matches
                  .where(playoff_level: "Districts")
                  .where("LOWER(opponent) = ?", opponent.downcase)
                  .first
      next unless match

      match.update_columns(result: info[:result], score_summary: info[:score])
      next if match.match_lines.exists?

      info[:lines].each do |ln|
        line = match.match_lines.create!(
          line_type:  ln[:type],
          position:   ln[:pos],
          set1_score: ln[:s1],
          set2_score: ln[:s2],
          set3_score: ln[:s3],
          result:     ln[:result],
          opponents:  ln[:opp].presence
        )
        ln[:players].each do |name|
          user = User.where("LOWER(name) = ?", name.downcase).first
          line.match_line_players.create!(user: user) if user
        end
      end
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
