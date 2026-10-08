require "test_helper"

class UstaLineTest < ActiveSupport::TestCase
  # Same layout as TennisLink's Individual Result "Send To Excel" file, made-up data.
  def results_html(player, rows)
    body = rows.map do |id, date, type, w1, w2, l1, l2, score|
      <<~ROW
        <tr><td><a href="#">#{id} </a></td><td>#{date}</td><td>#{type}</td>
        <td id="tdIndvWinner1Name">#{w1}</td><td id="tdIndvWinner2Name">#{w2}</td>
        <td id="tdIndvLoser1Name">#{l1}</td><td id="tdIndvLoser2Name">#{l2}</td>
        <td>#{score}</td><td>4.0 </td></tr>
      ROW
    end.join
    <<~HTML
      <table>
        <tr><td>Player Name</td></tr><tr><td>#{player}</td></tr>
        <tr><td class="bottom">USTA/MIDDLE STATES</td><td class="bottom">PHILADELPHIA</td><td colspan="3">Adult 40 &amp; Over Women 4.0</td></tr>
        #{body}
      </table>
    HTML
  end

  setup do
    @jane_file = UstaResultsParser.parse(results_html("Jane Tester", [
      [ "1012000001", "04/14/2026", "#1 Doubles", "Jane Tester", "Amy Partner", "Opp One", "Opp Two", "6-3, 6-4" ],
      [ "1012000002", "04/21/2026", "#2 Doubles", "Opp Three", "Opp Four", "Jane Tester", "Amy Partner", "6-2, 3-6, 1-0(8)" ]
    ]))
  end

  test "imports every line once and skips repeats from a teammate's file" do
    assert_equal({ added: 2, existing: 0 }, UstaLine.import(@jane_file))

    amy_file = UstaResultsParser.parse(results_html("Amy Partner", [
      [ "1012000001", "04/14/2026", "#1 Doubles", "Jane Tester", "Amy Partner", "Opp One", "Opp Two", "6-3, 6-4" ]
    ]))
    assert_equal({ added: 0, existing: 1 }, UstaLine.import(amy_file))
    assert_equal 2, UstaLine.count
  end

  test "shows each line from one player's side" do
    UstaLine.import(@jane_file)
    lines = UstaLine.for_player("jane tester").order(:match_date).to_a
    assert_equal 2, lines.size

    won = lines.first.entry_for("Jane Tester")
    assert won.won
    assert_equal "Amy Partner", won.partner
    assert_equal [ "Opp One", "Opp Two" ], won.opponents
    assert_equal [ "6-3", "6-4" ], won.set_scores

    lost = lines.last.entry_for("Jane Tester")
    assert_not lost.won
    assert_equal [ "2-6", "6-3", "0-1" ], lost.set_scores
    assert_nil lines.first.entry_for("Nobody")
  end

  test "summarises every player seen, opponents included" do
    UstaLine.import(@jane_file)
    by_name = RatingsHistory.player_summaries.index_by(&:name)
    assert_equal [ 1, 1 ], [ by_name["Jane Tester"].wins, by_name["Jane Tester"].losses ]
    assert_equal [ 0, 1 ], [ by_name["Opp One"].wins, by_name["Opp One"].losses ]
    assert_equal [ 1, 0 ], [ by_name["Opp Three"].wins, by_name["Opp Three"].losses ]
  end

  test "scores entered on Court Report show up without any upload" do
    line = entered_line
    entries = RatingsHistory.entries_for("Jane Tester")
    assert_equal 1, entries.size
    e = entries.first
    assert e.won
    assert_equal "Amy Partner", e.partner
    assert_equal [ "Opp One", "Opp Two" ], e.opponents
    assert_equal [ "6-3", "6-4" ], e.set_scores
    assert_equal "#1 Doubles", e.match_type

    line.update!(result: "loss", set1_score: "3-6", set2_score: "4-6")
    lost = RatingsHistory.entries_for("Opp One").first
    assert lost.won
    assert_equal [ "6-3", "6-4" ], lost.set_scores
  end

  test "an uploaded copy of the same line replaces the Court Report one" do
    entered_line
    UstaLine.import(@jane_file)
    entries = RatingsHistory.entries_for("Jane Tester")
    assert_equal 2, entries.size
    assert_equal [ "1012000002", "1012000001" ], entries.map { |e| e.line.usta_match_id }
  end

  private

  # Jane + Amy win 6-3, 6-4 on 4/14/2026 at #1 Doubles (position 2, after 1S).
  def entered_line
    owner = User.create!(name: "Team Owner", email: "ratings-owner@example.com")
    team = owner.tennis_teams.create!(name: "Test Aces", league_category: "USTA", league_name: "Adult 40 & Over")
    match = team.matches.create!(match_date: Time.zone.local(2026, 4, 14, 18), opponent: "Rivals")
    match.match_lines.create!(line_type: "singles", position: 1)
    line = match.match_lines.create!(line_type: "doubles", position: 2, result: "win",
                                     set1_score: "6-3", set2_score: "6-4", opponents: "Opp One / Opp Two")
    [ "Jane Tester", "Amy Partner" ].each do |nm|
      line.match_line_players.create!(user: User.create!(name: nm))
    end
    line
  end
end
