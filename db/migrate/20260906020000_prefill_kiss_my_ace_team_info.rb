# Pre-fills Kiss My Ace's TennisLink team details (district, flight, facility
# address) and its captain's phone, from the team's public TennisRecord /
# TennisLink page. Only sets fields that are currently blank, so it never
# overwrites anything a captain has already typed into the Edit Team Info form.
class PrefillKissMyAceTeamInfo < ActiveRecord::Migration[8.1]
  def up
    team = TennisTeam.where("LOWER(name) = ?", "kiss my ace").first
    return unless team

    updates = {}
    updates[:section]            = "Middle States"                          if team.section.blank?
    updates[:district]           = "Philadelphia"                           if team.district.blank?
    updates[:team_type]          = "Adult 40 & Over"                        if team.team_type.blank?
    updates[:flight]             = "4.0 Women Delches - Tues / Sub-Flight 2" if team.flight.blank?
    updates[:home_court]         = "Bryn Mawr Racquet Club"                 if team.home_court.blank?
    updates[:home_court_address] = "4 N Warner Ave, Bryn Mawr, PA 19010"    if team.home_court_address.blank?
    team.update_columns(updates) if updates.any?

    captain = team.captain
    if captain && captain.phone.blank?
      captain.update_columns(phone: "610-329-9911")
    end
  end

  def down
    # Data backfill — no automatic rollback.
  end
end
