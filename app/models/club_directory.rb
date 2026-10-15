# Where Bux-Mont and Del-Tri matches are played: each club's name and street
# address, copied from the leagues' public Tenniscores "Locations" pages
# (buxmont / deltri .tenniscores.com, "Locations" menu; checked Oct 15 2026).
# Clubs rarely move; if one does, update it here.
#
# Teams are named after their club ("Frog Hollow Orange", "Penn Oaks 2"), so a
# team or site name is matched to a club by its start ("aliases").
module ClubDirectory
  Club = Struct.new(:name, :address, :aliases, keyword_init: true) do
    def full
      "#{name}, #{address}"
    end

    def maps_url
      "https://www.google.com/maps/search/?api=1&query=#{ERB::Util.url_encode(full)}"
    end
  end

  CLUBS = {
    "Bux-Mont" => [
      Club.new(name: "Advantage Tennis", address: "951 N. Park Ave, Norristown, PA 19403", aliases: [ "Advantage" ]),
      Club.new(name: "Bucks County Racquet Club", address: "1150 Lord Sterling Road, Washington Crossing, PA 18977", aliases: [ "Bucks" ]),
      Club.new(name: "Doylestown Tennis Club", address: "10 Weldon Drive, Doylestown, PA 18901", aliases: [ "Doylestown" ]),
      Club.new(name: "Frog Hollow Racquet Club", address: "2115 Weber Road, Lansdale, PA 19446", aliases: [ "Frog" ]),
      Club.new(name: "Hopewell Tennis & Swim Center", address: "111 Titus Mill Road, Pennington, NJ 08534", aliases: [ "Hopewell" ]),
      Club.new(name: "Northampton Tennis and Fitness Club", address: "405 Newtown-Richboro Road, Richboro, PA 18954", aliases: [ "Northampton" ]),
      Club.new(name: "Northeast Racquet Club", address: "9379-81 Krewstown Road, Philadelphia, PA 19115", aliases: [ "Northeast" ]),
      Club.new(name: "Pennsbury", address: "375 W. Trenton Ave, Morrisville, PA 19067", aliases: [ "Pennsbury" ]),
      Club.new(name: "Tennis Zone and Fitness Center", address: "451 California Rd, Quakertown, PA 18951", aliases: [ "Tennis Zone" ]),
      Club.new(name: "Upper Dublin", address: "680 Tennis Ave, Ambler, PA 19002", aliases: [ "Upper Dublin" ])
    ],
    "Del-Tri" => [
      Club.new(name: "Brandywine Racquet Club", address: "430 Wilmington Pike, Glen Mills, PA 19342", aliases: [ "Brandywine" ]),
      Club.new(name: "DVTA", address: "4 N. Warner Avenue, Bryn Mawr, PA 19010", aliases: [ "DVTA" ]),
      Club.new(name: "Green Valley CC", address: "201 Ridge Pike, Lafayette Hill, PA 19444", aliases: [ "Green Valley" ]),
      Club.new(name: "Gulph Mills Tennis Club", address: "610 S. Henderson Rd, King of Prussia, PA 19406", aliases: [ "Gulph Mills" ]),
      Club.new(name: "HPTA", address: "601 Righters Ferry Rd, Bala Cynwyd, PA 19004", aliases: [ "HPTA" ]),
      Club.new(name: "Legacy Tennis", address: "4842 Ridge Ave, Philadelphia, PA 19129", aliases: [ "Legacy" ]),
      Club.new(name: "Penn Oaks Tennis & Fitness Club", address: "56 Penn Oaks Drive, West Chester, PA 19382", aliases: [ "Penn Oaks" ]),
      # Two different Radnor clubs: the longer alias wins.
      Club.new(name: "Radnor Racquet Club", address: "175 King of Prussia Road, Radnor, PA 19087", aliases: [ "Radnor Racquet" ]),
      Club.new(name: "Radnor Valley Country Club", address: "555 Sproul Rd, Villanova, PA 19085", aliases: [ "Radnor Valley" ]),
      Club.new(name: "Springfield YMCA", address: "194 W. Sproul Rd, Springfield, PA 19064", aliases: [ "Springfield" ]),
      Club.new(name: "Tennis Addiction Sports Club", address: "202 Phillips Road, Exton, PA 19341", aliases: [ "Tennis Addiction" ]),
      Club.new(name: "Upper Main Line Y", address: "1416 Berwyn Paoli Road, Berwyn, PA 19312", aliases: [ "Upper Main Line" ])
      # St Albans plays at "Neutral Sites", so no single address.
    ]
  }.freeze

  module_function

  def leagues
    CLUBS.keys
  end

  # The club a team or site name belongs to in this league, or nil.
  def find(text, league:)
    key = normalize(text)
    return nil if key.empty?

    candidates = CLUBS.fetch(league, []).flat_map do |club|
      ([ club.name ] + club.aliases).map { |a| [ normalize(a), club ] }
    end
    candidates.select { |a, _| key.start_with?(a) }.max_by { |a, _| a.length }&.last
  end

  def normalize(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end
end
