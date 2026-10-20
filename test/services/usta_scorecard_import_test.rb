require "test_helper"

# TennisLink match "Scorecard" export, same layout, made-up names.
class UstaScorecardImportTest < ActiveSupport::TestCase
  def self.line_row(ctl, label, home, visitor, winner, score)
    h = home.each_with_index.map { |n, i| %(<a id="ctl00_mainContent_rptScoreCard_#{ctl}_lnkHomePlayer#{i + 1}">#{n}</a><br>) }.join
    v = visitor.each_with_index.map { |n, i| %(<a id="ctl00_mainContent_rptScoreCard_#{ctl}_lnkVisitorPlayer#{i + 1}">#{n}</a><br>) }.join
    mark = %(<img src="mark.gif" id="ctl00_mainContent_rptScoreCard_#{ctl}_img#{winner == :home ? "Home" : "Visitor"}Player" />)
    <<~ROW
      <tr><td class="top">#{label}9:30 am</td><td>#{h}Completed</td><td>#{winner == :home ? mark : "&nbsp;"}</td>
      <td>Vs.</td><td>#{v}</td><td>#{winner == :visitor ? mark : "&nbsp;"}</td><td>#{score}</td></tr>
    ROW
  end

  HTML = <<~HTML.freeze
    <table><tr><td>Scorecard for Match # 1001 in Adult Tri-Level League Status: Confirmed by 48 hr rule Today's Date: 10/20/2026</td></tr></table>
    <table><tr><td>Rival Aces Team ID: *****</td><td>Vs.</td><td>Test-Hards Team ID: 35</td></tr>
    <tr><td>Date Scheduled: 9/30/2026 9:30 AM</td><td>Date Match Played: 9/30/2026</td></tr></table>
    <table>
    #{line_row("ctl00", "4.0 Doubles #1", [ "Rita Rival", "Rhea Rival" ], [ "Ann Ours", "Bea Ours" ], :visitor, "&nbsp;7-5&nbsp;4-6&nbsp;1-0")}
    #{line_row("ctl01", "3.5 Doubles #2", [ "Rose Rival", "Ruby Rival" ], [ "Cat Ours", "Dee Ours" ], :home, "&nbsp;6-4&nbsp;6-1")}
    </table>
  HTML

  setup do
    owner = User.create!(name: "Owner", email: "scorecard-owner@example.com")
    @team = owner.tennis_teams.create!(name: "Test Hards", league_category: "USTA",
                                       league_name: "USTA Adult Tri-Level", flight: "Tri Level Womens 4.0-3.0 Wednesday")
    @ann = User.create!(name: "Ann Ours")
    TeamMembership.create!(user: @ann, tennis_team: @team, role: "player")
    @match = @team.matches.create!(match_date: Time.zone.local(2026, 9, 30, 12), opponent: "Rival Aces")
    @parsed = UstaScorecardParser.parse(HTML)
  end

  test "parses every line, both pairs, the winner and winner-first sets" do
    assert @parsed.scorecard?
    assert_equal [ "Rival Aces", "Test-Hards", Date.new(2026, 9, 30) ], [ @parsed.home_team, @parsed.visitor_team, @parsed.date ]
    first = @parsed.lines.first
    assert_equal [ "4.0 Doubles", 1, :visitor, %w[7-5 4-6 1-0] ], [ first.label, first.number, first.winner, first.sets ]
    assert_equal [ "Ann Ours", "Bea Ours" ], first.visitor_players
  end

  test "apply! fills the match's lines from our side, ours-first" do
    import = UstaScorecardImport.new(@team, @parsed)
    assert import.ours?
    assert import.apply!

    lines = @match.reload.match_lines.order(:position).to_a
    assert_equal 2, lines.size
    assert_equal [ "win", "7-5", "4-6", "1-0" ], [ lines[0].result, lines[0].set1_score, lines[0].set2_score, lines[0].set3_score ]
    assert_equal [ "Ann Ours", "Bea Ours" ], lines[0].our_player_names
    assert_equal "Rita Rival / Rhea Rival", lines[0].opponents
    assert_equal [ "loss", "4-6", "1-6" ], [ lines[1].result, lines[1].set1_score, lines[1].set2_score ]
    assert_equal [ "tie", "1-1", "Confirmed by 48 hr rule" ], [ @match.result, @match.score_summary, @match.usta_status ]
    assert_includes lines[0].players, @ann
  end

  test "a scorecard for a different team changes nothing" do
    @team.update!(name: "Someone Else")
    import = UstaScorecardImport.new(@team, @parsed)
    assert_not import.ours?
    assert_not import.apply!
    assert_empty @match.reload.match_lines
  end
end
