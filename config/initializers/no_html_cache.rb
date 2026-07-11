# Force browsers never to cache HTML pages, so a deploy or data change is seen
# immediately (no stale "old version", no Private-tab workaround). This runs as
# the outermost middleware, so it has the final say over Rails' Rack::ETag /
# conditional-GET headers — it strips the validators and sets no-store on any
# text/html response. Fingerprinted CSS/JS/images are a different content-type
# and are left cached for speed.
class NoHtmlCache
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    if headers["Content-Type"].to_s.include?("text/html")
      headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
      headers["Pragma"] = "no-cache"
      headers.delete("ETag")
      headers.delete("Last-Modified")
    end
    [ status, headers, body ]
  end
end

Rails.application.config.middleware.insert_before(0, NoHtmlCache)
