module FriendliesHelper
  # Court times from 6:00 AM to 11:00 PM every 15 minutes, as [label, "HH:MM"].
  # A saved time that isn't on the list (e.g. 7:10) is kept so it isn't lost.
  def friendly_time_options(current = nil)
    times = (6 * 60..23 * 60).step(15).map { |m| format("%02d:%02d", m / 60, m % 60) }
    times = (times + [ current ]).sort if current.present? && !times.include?(current)
    times.map { |t| [ friendly_time_label(t), t ] }
  end

  def friendly_time_label(hhmm)
    hh, mm = hhmm.split(":").map(&:to_i)
    format("%d:%02d %s", (hh % 12).zero? ? 12 : hh % 12, mm, hh < 12 ? "AM" : "PM")
  end
end
