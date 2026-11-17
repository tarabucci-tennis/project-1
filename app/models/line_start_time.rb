# Start times for lineup lines ("10:30 AM"). Typed times are tidied so the
# same time always reads the same: "1030", "10:30am", "10:30 a.m." → "10:30 AM".
module LineStartTime
  module_function

  # "10:30 AM", or the text as typed if it isn't a clock time; nil if blank.
  def normalize(text)
    t = text.to_s.squish
    return nil if t.blank?
    m = t.downcase.delete(".").match(/\A(\d{1,2})(?::?(\d{2}))?\s*(am|pm)?\z/)
    return t unless m
    hour = m[1].to_i
    min = (m[2] || "00").to_i
    return t if hour > 23 || min > 59
    ampm = m[3]
    if ampm.nil?
      ampm = hour >= 12 || hour.between?(1, 6) ? "pm" : "am" # tennis: 1–6 is afternoon
      hour -= 12 if hour > 12
    end
    hour = 12 if hour.zero?
    format("%d:%02d %s", hour, min, ampm.upcase)
  end

  # Minutes after midnight, for putting times in order (unknown text last).
  def sort_key(text)
    t = normalize(text).to_s
    m = t.match(/\A(\d{1,2}):(\d{2}) (AM|PM)\z/)
    return 24 * 60 unless m
    h = m[1].to_i % 12
    h += 12 if m[3] == "PM"
    h * 60 + m[2].to_i
  end
end
