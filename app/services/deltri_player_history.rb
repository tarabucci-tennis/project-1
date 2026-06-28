require "net/http"

# Parses a player's public Del-Tri page (player.php?p=...) into their personal
# match history, grouped by division. On that page the player's own name is
# bold in each match card, which tells us which row is "ours" (partner + our
# set scores) vs. the opponents. Works for any player — no hard-coded names.
#
# Returns an array of hashes, newest first within each division:
#   { source_key:, division:, date_label:, played_on:, match_label:,
#     line_label:, partner:, opponents:, score:, result: }
class DeltriPlayerHistory
  UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
       "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36".freeze
  FETCH_TIMEOUT = 20

  def initialize(url)
    @url = url
  end

  def call
    parse(fetch(@url))
  end

  private

  def fetch(url)
    uri = URI(url)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: FETCH_TIMEOUT, read_timeout: FETCH_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = UA
      req["Accept"] = "text/html,application/xhtml+xml"
      req["Accept-Language"] = "en-US,en;q=0.9"
      http.request(req)
    end
    raise "HTTP #{res.code}" unless res.code.to_i == 200

    res.body.to_s
  end

  def parse(html)
    body = html.gsub(/<(script|style)[^>]*>.*?<\/\1>/mi, "")

    divisions = []
    body.to_enum(:scan, /Division\s+(\d+)\s*<span[^>]*>\(\s*(\d+)\s*Wins?,\s*(\d+)\s*Loss/i).each do
      divisions << { pos: Regexp.last_match.begin(0), label: "Division #{Regexp.last_match[1]}" }
    end

    blocks = []
    body.to_enum(:scan, /<div id="match_(\d+)"[^>]*class="match_type[^"]*"[^>]*>/i).each do
      blocks << { pos: Regexp.last_match.begin(0), id: Regexp.last_match[1] }
    end
    blocks.each_with_index { |b, i| b[:html] = body[b[:pos]...(blocks[i + 1] ? blocks[i + 1][:pos] : body.length)] }

    blocks.filter_map { |b| build_match(b, divisions) }
  end

  def build_match(block, divisions)
    h = block[:html]
    date_label = h[%r{(\d{1,2}/\d{1,2})}, 1]
    match_label = tidy_label(clean(h[/<a [^>]*>(.*?)<\/a>/mi, 1]))
    after = h[/<\/a>(.*?)(<div class="match_card|\z)/mi, 1].to_s
    line = clean(after)[/\A\s*(\d+)/, 1]
    result = clean(after)[/\b([WL])\b/, 1]
    return nil unless date_label && result

    rows = h.scan(/width:\s*480px;[^>]*>(.*?)<\/div>(.*?)<div class="clearfix"/mi).map do |(names_html, sets_html)|
      sets = sets_html.scan(/width:\s*20px;[^>]*>(.*?)<\/div>/mi).map { |(s)| clean(s) }.reject(&:blank?)
      { names_html: names_html, mine: names_html.match?(/<b>/i), sets: sets }
    end
    mine = rows.find { |r| r[:mine] }
    opp  = rows.find { |r| !r[:mine] }

    division = divisions.select { |d| d[:pos] < block[:pos] }.last

    {
      source_key:  block[:id],
      division:    division&.dig(:label),
      date_label:  date_label,
      played_on:   infer_date(date_label),
      match_label: match_label,
      line_label:  line ? "Line #{line}" : nil,
      partner:     partner_name(mine),
      opponents:   opp ? clean(opp[:names_html]) : nil,
      score:       set_score(mine, opp),
      result:      (result == "W" ? "win" : "loss")
    }
  end

  # The player's own name is the bold one; the partner is the other name.
  def partner_name(row)
    return nil unless row
    bold = row[:names_html][/<b>(.*?)<\/b>/im, 1]
    names = clean(row[:names_html]).split("/").map(&:strip)
    names.reject { |n| bold && n.casecmp?(clean(bold)) }.join(" / ").presence
  end

  # Keep only plausible real sets (a side reached 4–7). Drops Del-Tri's
  # trailing game-tally / tiebreak columns (e.g. "3-3", "1-0", "15-04").
  def set_score(mine, opp)
    return nil unless mine && opp
    mine[:sets].zip(opp[:sets]).filter_map do |a, b|
      next if a.nil? || b.nil?
      hi = [ a.to_i, b.to_i ].max
      next unless hi.between?(4, 7)
      "#{a}-#{b}"
    end.join(" ").presence
  end

  def tidy_label(label)
    # "Legacy 1 (H) vs Gulph Mills 1 (A)" -> "Legacy 1 vs Gulph Mills 1"
    label.to_s.gsub(/\s*\([HA]\)/i, "").gsub(/\s+/, " ").strip
  end

  # The page shows MM/DD with no year. Infer it from the current Del-Tri
  # season (Aug–Jul): months Aug–Dec belong to the season's first year.
  def infer_date(label)
    return nil unless label
    mm, dd = label.split("/").map(&:to_i)
    return nil unless mm && dd && mm.between?(1, 12)
    base = Date.current.month >= 8 ? Date.current.year : Date.current.year - 1
    year = mm >= 8 ? base : base + 1
    Date.new(year, mm, dd)
  rescue ArgumentError
    nil
  end

  def clean(str)
    str.to_s.gsub(/<[^>]+>/, "").gsub("&nbsp;", " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
  end
end
