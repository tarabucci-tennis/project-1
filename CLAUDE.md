# Project Configuration

## App Specification

**Framework:** Ruby on Rails 8.1.2
**Ruby:** 3.3.6
**Database:** SQLite (multi-database: primary, cache, queue, cable)
**Asset pipeline:** Propshaft
**Background jobs:** Solid Queue (running inside Puma via `SOLID_QUEUE_IN_PUMA`)
**WebSockets:** Solid Cable
**JavaScript:** Import Maps + Stimulus + Turbo (Hotwire)
**Web server:** Puma via Thruster (handles HTTP compression/caching)
**Containerization:** Docker (multi-stage build, production-optimized)

## DigitalOcean

Account: tarabucci@gmail.com
Token: stored in `doctl` auth config (run `doctl auth list` to verify)

### Deployed Infrastructure

| Resource | Details |
|----------|---------|
| Droplet ID | `555081556` |
| Droplet Name | `project-1` |
| Public IP | `146.190.112.29` |
| Region | `sfo3` |
| Size | `s-1vcpu-1gb` |
| Image | `docker-20-04` (Ubuntu 22.04 + Docker pre-installed) |
| Firewall ID | `b6a72fad-0194-438c-9603-589490137155` |
| Firewall | Ports 22 (SSH) and 80 (HTTP) open |
| Container Registry | `registry.digitalocean.com/tarabucci-tennis` |
| SSH Key ID | `54458995` (name: `do-deploy`) |

**App URL:** http://146.190.112.29

### Deployment Method

The app is deployed via Docker on a DigitalOcean Droplet. On first boot, a cloud-init user-data script:
1. Clones the repo from `https://github.com/tarabucci-tennis/project-1`
2. Runs `docker build -t project-1 .`
3. Starts the container: `docker run -d -p 80:80 -e RAILS_MASTER_KEY=... -v /root/storage:/rails/storage --restart unless-stopped project-1`

SQLite databases are persisted via a Docker volume mounted at `/root/storage` on the host.

### Re-deploying

To redeploy after pushing new code, SSH into the droplet and run:
```bash
cd /root/app && git pull && docker build -t project-1 . && docker stop project-1 && docker rm project-1 && docker run -d -p 80:80 -e RAILS_MASTER_KEY=<key> -v /root/storage:/rails/storage --name project-1 --restart unless-stopped project-1
```

## GitHub

Repo: `tarabucci-tennis/project-1` (public)
Branch: `claude/setup-planning-4PTsK`

## Scraping Strategy

Court Report needs tennis player/team data from two upstream sources: **TennisRecord** (aggregator, historical, stable) and **TennisLink** (USTA, real-time, volatile). Both expose public pages without auth. The plan is phased — build the lowest-risk tier first, prove it end-to-end, then expand.

### Current schema baseline (already built, no migration needed for these)

- `users`: `name`, `email`, `location`, `ntrp_rating`, `ntrp_rating_date`, `dynamic_rating`, `dynamic_rating_date`, `admin`
- `tennis_stats`: `user_id`, `year`, `matches_won/lost/total`, `sets_won/lost/total`, `games_won/lost/total`, `defaults`
- `tennis_teams`: `user_id`, `name`, `rating`, `gender`, `section`, `start_date`, `team_type`

**Gems NOT yet in Gemfile** (Phase 1 must add): `nokogiri`, `httparty` (or `faraday`). No `nokogiri` means no HTML parsing yet.

### Tier 1 — TennisRecord scraping (LOWEST RISK, START HERE)

TennisRecord is a public aggregator site; WebFetch against a player profile URL has already been confirmed to return rich parseable HTML (rating, W-L, sets, games, recent teams, yearly breakdown, location). Data has a few-day lag but is stable for historical queries.

### Tier 2 — TennisLink scraping (MEDIUM RISK, REAL-TIME)

Public team schedule and standings pages are accessible without USTA login. Real-time match results. Risk: HTML changes frequently; some pages may be JS-heavy and require a headless browser (heavier dep). Needs verification in an incognito window before committing to build.

### Tier 3 — TennisLink auth-required pages (AVOID UNLESS NECESSARY)

Personal dynamic rating, private roster features. Requires credential storage on droplet, OAuth login flow, session cookies. High maintenance risk (USTA changes login flow), security burden, legal gray area. **Strongly discouraged** unless Tiers 1+2 prove insufficient.

### Phased build plan

**Phase 1 — TennisRecord player scraper (foundation, ~2 hrs, 1 session)**
1. Add `nokogiri` + `httparty` to Gemfile; `bundle install`.
2. Migration: add `users.tennisrecord_url`, `users.tr_last_fetched_at`. (Most data columns already exist on `users` and `tennis_stats`.)
3. `app/services/tennis_record_scraper.rb` — `.fetch_player(url)` returns a struct with `ntrp_rating`, `dynamic_rating`, `location`, yearly stat rows, recent teams.
4. `User#refresh_from_tennis_record!` — calls scraper, updates `users` columns, upserts `tennis_stats` rows for each year returned, touches `tr_last_fetched_at`.
5. "Refresh from TennisRecord" button on profile page (`profiles_controller`) that POSTs and triggers the refresh synchronously for one user.
6. `bin/rails runner` batch script to seed all users in one pass with a 3s sleep between requests.

**Exit criteria Phase 1:** Tap the refresh button on your own profile, page reloads showing data pulled live from TennisRecord HTML into Court Report's DB. Verified in browser at http://146.190.112.29.

**Phase 2 — Nightly auto-refresh (~1.5 hrs)**
1. `RefreshTennisRecordJob < ApplicationJob` iterating all users with a `tennisrecord_url`.
2. Solid Queue recurring schedule (Rails 8 supports `config/recurring.yml`): nightly at 3 AM.
3. Rate limit: `sleep 3` between requests inside the job.
4. Per-user rescue: log + mark `tr_last_fetched_at` as failed, continue the batch.

**Phase 3 — TennisLink team scraping (~2–4 hrs)**
1. Incognito-test TennisLink public standings/schedule URLs first (user task).
2. Add `tennis_teams.tennislink_url`, `tennis_teams.tl_last_fetched_at`.
3. `app/services/tennis_link_scraper.rb` — `.fetch_team(url)` returns division opponents + their rosters.
4. Opponent players become `User` records (flagged `admin: false`, no email) so they can be cross-linked to TennisRecord later.
5. "Refresh from TennisLink" button on team page.

**Phase 4 — Cross-source linking (optional, later)**
Auto-match opponent players scraped from TennisLink to TennisRecord profiles by name + section. Run the TennisRecord scraper against those matches to get opponent ratings. Requires a fuzzy-match step and a manual review UI for ambiguous matches.

### Known constraints for scraper build

- **Dev sandbox has HTTP proxy** (`http_proxy` env var). HTTParty requests work through it, but production droplet won't have this — make sure scraper code doesn't hardcode the proxy.
- **Sandbox cannot test deployed URL directly** — user must browser-verify Phase 1 after deploy.
- **Rate limiting is non-negotiable**: TennisRecord is a volunteer-run site. Never more than one request per 3 seconds. Batch jobs should spread across the night.
- **Legal**: Scraping public pages for personal use is generally fine; redistributing or commercializing this data is not. Court Report is personal-use only — keep it that way.

### User inputs still needed before Phase 1 starts

1. Canonical TennisRecord URL for the seed user (Mariano).
2. Prioritized list of data fields (must-have vs nice-to-have).
3. Incognito test of TennisLink public pages (Phase 3 gate, not Phase 1 blocker).

## Learnings

### Deployment Environment Constraints
- **No `ssh-keygen`** in this sandbox — had to use `openssl genpkey` + Python stdlib to generate RSA keys and manually convert to SSH authorized_keys format.
- **No Docker daemon** running in this environment — cannot build Docker images locally; all builds must happen on the remote server.
- **Outbound proxy** (`http_proxy`) is set for all HTTP/HTTPS traffic in this environment; `--noproxy '*'` bypasses the proxy but then has no direct internet access. This means we cannot directly test deployed URLs from this environment — the user must verify in their browser.
- **No `ssh` client** available — cannot SSH into Droplets from this environment for debugging.

### DigitalOcean App Platform
- App Platform requires GitHub OAuth to be connected via the DO dashboard (browser-based) before you can deploy from a GitHub repo. The CLI error is: `GitHub user not authenticated`. There is no CLI workaround.
- The `docker-20-04` Marketplace image has Docker pre-installed on Ubuntu 22.04 and is the fastest way to get a Docker-ready Droplet.

### Rails 8 Dockerfile
- The default Rails 8 Dockerfile uses `COPY vendor/* ./vendor/` — this works as long as `vendor/.keep` exists (Rails generates it). An empty `vendor/` with no `.keep` would cause a Docker build failure.
- `SECRET_KEY_BASE_DUMMY=1` is used during `assets:precompile` in the build stage to avoid needing the real secret at build time.
- The `-j 1` flag on `bootsnap precompile` disables parallel compilation to avoid a QEMU bug — important for cross-architecture builds.

### SSH Key Generation Without ssh-keygen
- OpenSSL can generate RSA keys: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096`
- Converting OpenSSL RSA PKCS#1 DER format to SSH `authorized_keys` format requires parsing ASN.1 DER manually and encoding with `struct.pack('>I', ...)` length prefixes — doable in Python stdlib with no external dependencies.
