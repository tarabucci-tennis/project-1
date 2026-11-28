# When a match or calendar entry is over. Times are stored as the wall-clock
# time people typed (the app runs on UTC, the players are on Eastern), so
# "now" is compared as an Eastern wall-clock time too.
module PlayClock
  module_function

  ZONE = "Eastern Time (US & Canada)".freeze
  DEFAULT_LENGTH = 2.hours

  # Now on the players' clock, in the same form the times are stored.
  def now
    l = Time.current.in_time_zone(ZONE)
    Time.utc(l.year, l.month, l.day, l.hour, l.min, l.sec)
  end

  # The end of play: the end of a typed range ("9:30 – 11:30 AM"), else the
  # start plus two hours, else (no usable time) the end of that day.
  def ends_at(date, time_text)
    day = Time.utc(date.year, date.month, date.day)
    t = LineStartTime.normalize(time_text).to_s
    if (m = t.match(/–\s*(\d{1,2}):(\d{2}) (AM|PM)\z/))
      return day + minutes(m[1], m[2], m[3]).minutes
    end
    key = LineStartTime.sort_key(t)
    return day.end_of_day if key >= 24 * 60
    day + key.minutes + DEFAULT_LENGTH
  end

  # Today's date on the players' clock (QA Nov 27 2026: the calendar used the
  # server's UTC date, so from 7 PM Eastern it marked tomorrow as today).
  def today
    now.to_date
  end

  def over?(date, time_text)
    ends_at(date, time_text) <= now
  end

  def minutes(h, m, period)
    (h.to_i % 12 + (period == "PM" ? 12 : 0)) * 60 + m.to_i
  end
end
