# A link to the official scorecard for a match (e.g. its TennisLink page),
# pasted by a captain on Edit Match and shown in the result pop-up.
class AddScorecardUrlToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :scorecard_url, :string
  end
end
