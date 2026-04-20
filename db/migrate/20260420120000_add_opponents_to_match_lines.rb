class AddOpponentsToMatchLines < ActiveRecord::Migration[8.1]
  def change
    add_column :match_lines, :opponents, :string
  end
end
