require "date"

# Parses a USTA TennisLink match "Scorecard" export (open a match from the
# Match Summary, then "Send To Excel"). Like the other TennisLink downloads
# it's an HTML table despite the .xls name. Unlike them it has every line:
#
#   * header  — match ID, status, home and visiting team, date played
#   * lines   — "4.0 Doubles #1": both pairs, the set scores and which side
#               won. TennisLink marks the winner with a check image
#               (imgHomePlayer / imgVisitorPlayer) and writes the set scores
#               WINNER FIRST ("7-5 4-6 1-0"), whichever side that is.
#
# Plain string scanning, no gems. Nothing here touches the database, and
# captain phone numbers / emails in the file are never read.
class UstaScorecardParser
  Line = Struct.new(:label, :line_type, :number, :home_players, :visitor_players,
                    :winner, :sets, :state, keyword_init: true)
  Result = Struct.new(:match_id, :status, :date, :home_team, :visitor_team, :lines, keyword_init: true) do
    def scorecard?
      lines.any? && home_team.present? && visitor_team.present?
    end
  end

  def self.parse(html)
    new(html).parse
  end

  def initialize(html)
    @html = html.to_s
    @text = clean(@html)
  end

  def parse
    home, visitor = team_names
    Result.new(
      match_id: @text[/Scorecard for Match #\s*(\d+)/, 1],
      status: @text[/Status:\s*(.*?)\s*Today's Date/i, 1]&.strip.presence,
      date: parse_date(@text[%r{Date Match Played:\s*(\d{1,2}/\d{1,2}/\d{4})}, 1]) ||
            parse_date(@text[%r{Date Scheduled:\s*(\d{1,2}/\d{1,2}/\d{4})}, 1]),
      home_team: home,
      visitor_team: visitor,
      lines: lines
    )
  end

  private

  # "Tri-Aces Team ID: *****" … "Tri-Hards Team ID: 3509182866"
  def team_names
    cells = @html.scan(/<td[^>]*>(.*?)<\/td>/im).map { |(c)| clean(c) }
    cells.filter_map { |c| c[/\A(.+?)\s*Team ID:/, 1]&.strip }.first(2)
  end

  # One table row per line, its controls numbered rptScoreCard_ctl00, _ctl01…
  def lines
    @html.scan(/<tr[^>]*>(.*?)<\/tr>/im).filter_map do |(row)|
      next unless row.include?("lnkHomePlayer")
      cells = row.scan(/<td[^>]*>(.*?)<\/td>/im).map(&:first)
      head = clean(cells.first)
      label = head[/\A(.*?(?:Singles|Doubles))/i, 1]&.strip
      next unless label

      # "#19:30 am" is line #1 at 9:30 am; "#110:00 am" is #1 at 10:00 am.
      number = head[/#(\d)(?:\d{1,2}:\d{2})?/, 1].to_i
      Line.new(
        label: label,
        line_type: label =~ /singles/i ? "singles" : "doubles",
        number: number.positive? ? number : nil,
        home_players: players(row, "Home"),
        visitor_players: players(row, "Visitor"),
        winner: (if row.include?("imgHomePlayer") then :home elsif row.include?("imgVisitorPlayer") then :visitor end),
        sets: clean(cells.last).scan(/\d+\s*-\s*\d+/).map { |s| s.delete(" ") },
        state: clean(row)[/\b(Completed|Default\w*|Retire\w*|Timed Match)\b/i, 1]
      )
    end
  end

  def players(row, side)
    row.scan(/id="[^"]*lnk#{side}Player\d"[^>]*>(.*?)<\/a>/im).map { |(n)| clean(n) }.reject(&:empty?)
  end

  def parse_date(str)
    m = str.to_s.match(%r{(\d{1,2})/(\d{1,2})/(\d{4})})
    m && Date.new(m[3].to_i, m[1].to_i, m[2].to_i)
  rescue ArgumentError
    nil
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, " ").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub("&#39;", "'")
       .gsub(/\s+/, " ").strip
  end
end
