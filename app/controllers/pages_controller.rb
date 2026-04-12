require "net/http"
require "csv"

class PagesController < ApplicationController
  SHEET_CSV_URL = "https://docs.google.com/spreadsheets/d/1OvOObnk_Sq5wZOX8sQHnUfn_PNTXrgSgGnqqS8QeIjI/export?format=csv".freeze

  def home
    if current_user
      redirect_to teams_path
    else
      render "courtreport", layout: false
    end
  end

  def stats_test
    @rows = []
    @headers = []
    @error = nil

    begin
      response = fetch_with_redirects(SHEET_CSV_URL)

      if response.is_a?(Net::HTTPSuccess)
        csv = CSV.parse(response.body, headers: true)
        @headers = csv.headers.compact
        @rows = csv.map { |row| row.to_h }
      else
        @error = "Failed to fetch sheet: #{response.code} #{response.message}"
      end
    rescue => e
      @error = "Error: #{e.message}"
    end
  end

  private

  def fetch_with_redirects(url, limit = 10)
    raise "Too many redirects" if limit == 0
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.get(uri.request_uri)
    end
    if response.is_a?(Net::HTTPRedirection)
      fetch_with_redirects(response["location"], limit - 1)
    else
      response
    end
  end
end
