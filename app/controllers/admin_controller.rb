require "net/http"
require "openssl"

class AdminController < ApplicationController
  before_action :require_admin

  TENNISLINK_HOST = "tennislink.usta.com".freeze
  TENNISLINK_PATH = "/teamtennis/main/IndividualPlayerRecord.aspx".freeze
  FETCH_TIMEOUT_SECONDS = 15

  def tennislink_test
    @person_id = params[:person_id].to_s.strip
    @year = params[:year].presence || Date.current.year.to_s

    @fetched_url = nil
    @status_code = nil
    @body = nil
    @elapsed_ms = nil
    @error = nil

    return if @person_id.blank?

    uri = URI::HTTPS.build(
      host: TENNISLINK_HOST,
      path: TENNISLINK_PATH,
      query: URI.encode_www_form(PersonID: @person_id, ChampYear: @year)
    )
    @fetched_url = uri.to_s

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: FETCH_TIMEOUT_SECONDS, read_timeout: FETCH_TIMEOUT_SECONDS) do |http|
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "Mozilla/5.0 (compatible; CourtReport/1.0; +https://yourcourtreport.com)"
        req["Accept"] = "text/html,application/xhtml+xml"
        res = http.request(req)
        @status_code = res.code.to_i
        @body = res.body.to_s
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      @error = "TIMEOUT: #{e.class} — #{e.message}"
    rescue StandardError => e
      @error = "#{e.class}: #{e.message}"
    ensure
      @elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    end
  end

  # Pull the latest results from the public Google Sheet (match results +
  # posted lineups) AND the public Del-Tri site (opponent league standings),
  # then import both. Idempotent.
  def sync_scores
    result = SheetScoreSync.new.call
    standings = DeltriStandings.new.call
    deltri = DeltriResults.new.call
    players = DeltriPlayerImport.sync_all
    playoffs = TennisrecordPlayoffs.new.call
    RatingCalculator.recompute!

    pieces = []
    pieces << result.to_s if result.summaries.any?
    pieces << "Standings — #{standings}" if standings.updated.any?
    pieces << "Del-Tri results — #{deltri}" if deltri.updated.any?
    pieces << "Player history — #{players}" if players.imported.any?
    pieces << "Postseason — #{playoffs}" if playoffs.updated.any?

    if pieces.any?
      redirect_to teams_path, notice: "Synced — #{pieces.join(' | ')}"
    else
      messages = (result.notes + standings.notes + deltri.notes + players.notes + playoffs.notes).reject(&:blank?)
      redirect_to teams_path, alert: "Sync ran but found nothing to update. #{messages.join('; ')}"
    end
  rescue StandardError => e
    redirect_to teams_path, alert: "Sync failed: #{e.message}"
  end

  # Upload a USTA TennisLink "Send To Excel" export and see it parsed. This is
  # the read-only preview step: it shows what we pulled out of the file (every
  # league, every match, from your point of view) so we can confirm it's right
  # before a later step writes it into your teams. Nothing is saved here.
  def usta_import
    @result = nil
    @error = nil
    return unless request.post?

    file = params[:file]
    if file.blank?
      @error = "Choose your USTA export file first (the .xls from 'Send To Excel')."
      return
    end

    html = file.read.to_s.dup.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    @result = UstaResultsParser.parse(html)
    if @result.leagues.empty?
      @error = "No results found in that file. Make sure it's the 'Send To Excel' download from your USTA Individual Player Record page."
    end
  rescue StandardError => e
    @error = "Couldn't read that file (#{e.message})."
  end
end
