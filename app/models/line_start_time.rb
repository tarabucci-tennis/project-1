# Start times for lineup lines ("10:30 AM"). Typed times are tidied so the
# same time always reads the same: "1030", "10:30am", "10:30 a.m." → "10:30 AM".
module LineStartTime
  module_function

  # "10:30 AM", or the text as typed if it isn't a clock time; nil if blank.
  def normalize(text)
    t = text.to_s.squish
    return nil if t.blank?
    range = normalize_range(t)
    return range if range
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

  # "12:00 PM to 1:30 PM", "12-1:30" → "12:00 – 1:30 PM" (en dash, the period
  # said once when both ends share it, like Friendly#time_label); nil if the
  # text isn't two clock times.
  def normalize_range(t)
    parts = t.split(/\s*(?:\bto\b|–|—|-)\s*/i, 2)
    return nil unless parts.size == 2
    a = normalize(parts[0])
    b = normalize(parts[1])
    return nil unless clock?(a) && clock?(b)
    a_time, a_period = a.split(" ")
    b_time, b_period = b.split(" ")
    # "12-1:30": the end decides the period when the start had none typed.
    a_period = b_period if !parts[0].match?(/[ap]\.?m/i) && a_period != b_period && sort_key("#{a_time} #{b_period}") < sort_key(b)
    a_period == b_period ? "#{a_time} – #{b_time} #{b_period}" : "#{a_time} #{a_period} – #{b_time} #{b_period}"
  end

  def clock?(t) = t.to_s.match?(/\A\d{1,2}:\d{2} (AM|PM)\z/)

  # Bare clock times inside free text ("D1 10:30 with Rachel") get AM/PM by
  # the same tennis rule: "D1 10:30 AM with Rachel". Times already marked are left alone.
  def mark_times(text)
    text.to_s.gsub(/(?<![\d:])(\d{1,2}):(\d{2})(?![\d:])(?!\s*[ap]\.?m)/i) { normalize("#{$1}:#{$2}") }
  end

  # Minutes after midnight, for putting times in order (unknown text last).
  def sort_key(text)
    t = normalize(text).to_s
    # A range sorts by its start ("12:00 – 1:30 PM" → noon).
    m = t.match(/\A(\d{1,2}):(\d{2})(?: (AM|PM))?(?:\z| –)/)
    return 24 * 60 unless m
    period = m[3] || t[/(AM|PM)\z/]
    return 24 * 60 unless period
    h = m[1].to_i % 12
    h += 12 if period == "PM"
    h * 60 + m[2].to_i
  end
end
