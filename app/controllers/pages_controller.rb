require "net/http"
require "csv"

class PagesController < ApplicationController
  SABALENKA_QUOTES = [
    "I just want to keep fighting and keep believing.",
    "Every match is a new opportunity to show what I can do.",
    "I love the pressure. It makes me feel alive on the court.",
    "You have to believe in yourself even when no one else does.",
    "Losing is part of the journey. It makes winning so much sweeter.",
    "I play with my heart. That's the only way I know how.",
    "Champions are made in the moments when they want to quit but don't.",
    "I wake up every day wanting to be better than I was yesterday.",
    "Tennis is my life. I give everything I have every single time.",
    "The crowd gives me energy. I feed off their passion."
  ].freeze

  SHEET_CSV_URL = "https://docs.google.com/spreadsheets/d/1OvOObnk_Sq5wZOX8sQHnUfn_PNTXrgSgGnqqS8QeIjI/export?format=csv".freeze

  def home
    return redirect_to login_path unless current_user
    redirect_to tennis_path unless current_user.admin?
  end

  def tennis
    return redirect_to login_path unless current_user
    @quote = SABALENKA_QUOTES.sample
  end

  def stats_test
    @rows = []
    @error = nil

    begin
      response = Net::HTTP.get_response(URI(SHEET_CSV_URL))
      if response.is_a?(Net::HTTPRedirection)
        response = Net::HTTP.get_response(URI(response["location"]))
      end

      if response.is_a?(Net::HTTPSuccess)
        csv = CSV.parse(response.body, headers: true)
        @headers = csv.headers
        @rows = csv.to_a.map(&:to_h)
      else
        @error = "Failed to fetch sheet: #{response.code} #{response.message}"
      end
    rescue => e
      @error = "Error: #{e.message}"
    end
  end
end
