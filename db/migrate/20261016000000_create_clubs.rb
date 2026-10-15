# Clubs where Bux-Mont and Del-Tri matches are played, with their addresses,
# so they can be edited on the site (Standings tab of those teams) instead of
# living in the code. Starting data is copied from each league's public
# Tenniscores "Locations" page (checked Oct 15 2026).
#
# Idempotent: adds a club only if that league doesn't already have one with
# the same name, and never changes an existing row.
class CreateClubs < ActiveRecord::Migration[8.1]
  class Club < ActiveRecord::Base
    self.table_name = "clubs"
  end

  # league, name, address, team-name starts (comma separated)
  START = [
    [ "Bux-Mont", "Advantage Tennis", "951 N. Park Ave, Norristown, PA 19403", "Advantage" ],
    [ "Bux-Mont", "Bucks County Racquet Club", "1150 Lord Sterling Road, Washington Crossing, PA 18977", "Bucks" ],
    [ "Bux-Mont", "Doylestown Tennis Club", "10 Weldon Drive, Doylestown, PA 18901", "Doylestown" ],
    [ "Bux-Mont", "Frog Hollow Racquet Club", "2115 Weber Road, Lansdale, PA 19446", "Frog" ],
    [ "Bux-Mont", "Hopewell Tennis & Swim Center", "111 Titus Mill Road, Pennington, NJ 08534", "Hopewell" ],
    [ "Bux-Mont", "Northampton Tennis and Fitness Club", "405 Newtown-Richboro Road, Richboro, PA 18954", "Northampton" ],
    [ "Bux-Mont", "Northeast Racquet Club", "9379-81 Krewstown Road, Philadelphia, PA 19115", "Northeast" ],
    [ "Bux-Mont", "Pennsbury", "375 W. Trenton Ave, Morrisville, PA 19067", "Pennsbury" ],
    [ "Bux-Mont", "Tennis Zone and Fitness Center", "451 California Rd, Quakertown, PA 18951", "Tennis Zone" ],
    [ "Bux-Mont", "Upper Dublin", "680 Tennis Ave, Ambler, PA 19002", "Upper Dublin" ],
    [ "Del-Tri", "Brandywine Racquet Club", "430 Wilmington Pike, Glen Mills, PA 19342", "Brandywine" ],
    [ "Del-Tri", "DVTA", "4 N. Warner Avenue, Bryn Mawr, PA 19010", "DVTA" ],
    [ "Del-Tri", "Green Valley CC", "201 Ridge Pike, Lafayette Hill, PA 19444", "Green Valley" ],
    [ "Del-Tri", "Gulph Mills Tennis Club", "610 S. Henderson Rd, King of Prussia, PA 19406", "Gulph Mills" ],
    [ "Del-Tri", "HPTA", "601 Righters Ferry Rd, Bala Cynwyd, PA 19004", "HPTA" ],
    [ "Del-Tri", "Legacy Tennis", "4842 Ridge Ave, Philadelphia, PA 19129", "Legacy" ],
    [ "Del-Tri", "Penn Oaks Tennis & Fitness Club", "56 Penn Oaks Drive, West Chester, PA 19382", "Penn Oaks" ],
    [ "Del-Tri", "Radnor Racquet Club", "175 King of Prussia Road, Radnor, PA 19087", "Radnor Racquet" ],
    [ "Del-Tri", "Radnor Valley Country Club", "555 Sproul Rd, Villanova, PA 19085", "Radnor Valley" ],
    [ "Del-Tri", "Springfield YMCA", "194 W. Sproul Rd, Springfield, PA 19064", "Springfield" ],
    [ "Del-Tri", "Tennis Addiction Sports Club", "202 Phillips Road, Exton, PA 19341", "Tennis Addiction" ],
    [ "Del-Tri", "Upper Main Line Y", "1416 Berwyn Paoli Road, Berwyn, PA 19312", "Upper Main Line" ]
  ].freeze

  def up
    create_table :clubs do |t|
      t.string :league, null: false
      t.string :name, null: false
      t.string :address
      t.string :aliases
      t.timestamps
    end
    add_index :clubs, [ :league, :name ], unique: true

    Club.reset_column_information
    START.each do |league, name, address, aliases|
      next if Club.where(league: league).where("LOWER(name) = ?", name.downcase).exists?
      Club.create!(league: league, name: name, address: address, aliases: aliases)
    end
  end

  def down
    drop_table :clubs
  end
end
