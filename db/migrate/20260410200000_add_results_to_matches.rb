class AddResultsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :result, :string        # "win", "loss", or nil (not played yet)
    add_column :matches, :score_summary, :string # e.g. "3-2" (lines won - lines lost)
    add_column :matches, :home_away, :string      # "home" or "away"
  end
end
