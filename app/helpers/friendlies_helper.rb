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

  # Places to suggest while typing "Where": the league clubs, the user's teams'
  # home courts and the places of their own earlier friendlies. Everything is
  # already in Court Report, so nothing typed leaves the site.
  # Each is { name:, address:, value: } where value is what fills the box.
  def friendly_place_suggestions(user)
    places = Club.order(:name).map { |c| { name: c.name, address: c.address.to_s } }
    if user
      user.member_teams.distinct.each do |t|
        next if t.home_court.blank?
        places << { name: t.home_court.to_s.squish, address: t.home_court_address.to_s.squish }
      end
      user.organized_friendlies.where.not(location: [ nil, "" ]).order(starts_at: :desc).limit(30).pluck(:location).each do |loc|
        name, address = loc.to_s.squish.split(/,\s*/, 2)
        places << { name: name, address: address.to_s }
      end
    end
    places.reject { |p| p[:name].blank? }
          .uniq { |p| p[:name].downcase }
          .map { |p| p.merge(value: [ p[:name], p[:address] ].compact_blank.join(", ")) }
  end
end
