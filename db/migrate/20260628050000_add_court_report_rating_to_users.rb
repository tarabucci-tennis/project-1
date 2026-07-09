class AddCourtReportRatingToUsers < ActiveRecord::Migration[8.1]
  def change
    # A live, self-contained rating computed from the scores entered in Court
    # Report (see RatingCalculator). Updates the instant a result is saved.
    add_column :users, :court_report_rating, :decimal, precision: 4, scale: 2
    add_column :users, :court_report_rating_lines, :integer, default: 0, null: false
  end
end
