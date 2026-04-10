# Project Configuration

## App Specification

**Framework:** Ruby on Rails 8.1.2
**Ruby:** 3.3.6
**Database:** SQLite (multi-database: primary, cache, queue, cable)
**Asset pipeline:** Propshaft
**Background jobs:** Solid Queue (running inside Puma via `SOLID_QUEUE_IN_PUMA`)
**WebSockets:** Solid Cable
**JavaScript:** Import Maps + Stimulus + Turbo (Hotwire)
**CSS:** Custom (no framework — tennis court-inspired dark green theme)
**Web server:** Puma via Thruster (handles HTTP compression/caching)
**Containerization:** Docker (multi-stage build, production-optimized)

## App Features

### Pages & Routes

| Route | Controller | Description |
|-------|-----------|-------------|
| `GET /` | `pages#home` | Tara's Sandbox landing page with app cards (admins only — non-admins redirect to `/tennis`) |
| `GET /tennis` | `pages#tennis` | Tennis hub with court-line design, random Sabalenka quote, feature cards (Leagues, Scores, Friends) |
| `GET /profile` | `profiles#show` | Player profile: NTRP rating with visual meter, dynamic rating, recent teams table, match history by year |
| `GET /login` | `sessions#new` | Email-only login form |
| `POST /session` | `sessions#create` | Authenticate by email (no password) |
| `DELETE /session` | `sessions#destroy` | Sign out |
| `GET /users` | `users#index` | Admin: player management panel |
| `POST /users` | `users#create` | Admin: add new player |
| `GET /users/:id/edit` | `users#edit` | Admin: edit player details |
| `PATCH /users/:id` | `users#update` | Admin: update player |
| `DELETE /users/:id` | `users#destroy` | Admin: remove player |
| `GET /up` | `rails/health#show` | Health check |

### Authentication & Authorization

- **Email-only login** — no passwords, session-based via `session[:user_id]`
- `current_user` helper in `ApplicationController`
- Unauthenticated users redirect to `/login` from `/` and `/tennis`
- **Admin role:** `admin` boolean on User model
  - Admins see full sandbox homepage, "Players" link, "Project 2" placeholder in nav
  - Non-admins redirect from `/` to `/tennis` — can only see tennis pages
- Admin-only routes protected by `require_admin` before_action

### Models

**User** — `name` (required), `email` (unique, optional), `admin` (boolean), `location`, `ntrp_rating`, `ntrp_rating_date`, `dynamic_rating`, `dynamic_rating_date`
- `has_many :tennis_teams, dependent: :destroy`
- `has_many :tennis_stats, dependent: :destroy`

**TennisTeam** — `name`, `team_type`, `section`, `gender`, `rating`, `start_date`
- `belongs_to :user`

**TennisStat** — `year`, `matches_total/won/lost`, `sets_total/won/lost`, `games_total/won/lost`, `defaults`
- `belongs_to :user`
- Methods: `match_wpct`, `set_wpct`, `game_wpct`
- Scope: `chronological` (orders by year DESC)

### Seed Data

- **Tara Bucci** — admin, 4.0 NTRP, dynamic 3.94, 5 teams, stats for 2026/2025/2024
- **Jody Staples** — non-admin, no email yet

### Navigation

- **Left:** "Tara's Sandbox" brand (clickable for admins, static for non-admins)
- **Center:** "Tennis" link, "Project 2" placeholder (admin-only, greyed out)
- **Right:** "Players" (admin-only), user name (links to profile), Sign Out

### Visual Design

- Dark green background (`#1a472a`) — tennis court-inspired
- Yellow accent (`#ccff00`) for highlights
- Animated bouncing tennis ball on tennis page
- 10 rotating Sabalenka quotes (random server-side)
- SVG icons on feature cards (trophy, bar chart, people)
- Responsive design, custom CSS (no Tailwind/Bootstrap)

## CI/CD

### GitHub Actions — CI (`.github/workflows/ci.yml`)

Runs on PR and push to `main`:
- **scan_ruby:** Brakeman security scan + bundler-audit
- **scan_js:** `bin/importmap audit`
- **lint:** RuboCop
- **test:** `bin/rails test`
- **system-test:** Capybara with Chrome (uploads failed screenshots)

### GitHub Actions — Deploy (`.github/workflows/deploy.yml`)

Triggers on push to `main` or `claude/**` branches (auto-deploy, no PR needed):
1. SSH into droplet via `appleboy/ssh-action@v1.0.3`
2. Clone repo if not present at `/root/app`
3. Fetch latest, checkout branch, reset to remote
4. `docker build -t project-1 .`
5. Stop/remove old container, start new one (port 80, volume mount, RAILS_MASTER_KEY)
6. Wait 5s, then `docker exec project-1 bin/rails db:migrate db:seed`

**GitHub Secrets required:** `DEPLOY_HOST`, `DEPLOY_SSH_KEY`, `RAILS_MASTER_KEY`

### Dependabot

Weekly updates for bundler and GitHub Actions (max 10 open PRs each).

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

### Re-deploying (Manual)

To redeploy manually, SSH into the droplet and run:
```bash
cd /root/app && git pull && docker build -t project-1 . && docker stop project-1 && docker rm project-1 && docker run -d -p 80:80 -e RAILS_MASTER_KEY=<key> -v /root/storage:/rails/storage --name project-1 --restart unless-stopped project-1
```

Note: Pushing to `main` or any `claude/**` branch auto-deploys via GitHub Actions.

## GitHub

Repo: `tarabucci-tennis/project-1` (public)

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
