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

## Application

The app is **Tara's Sandbox**, a personal landing page with a Tennis sub-app.

### Routes

| Path | Purpose |
|------|---------|
| `/` | Tara's Sandbox landing — admin-only. Non-admins redirect to `/tennis`; unauthenticated users redirect to `/login`. |
| `/tennis` | Tennis homepage: dark-green court theme, animated ball, random Sabalenka quote (10-quote pool, picked server-side), three feature cards (Leagues / Scores / Friends). |
| `/profile` | Player profile: NTRP rating card with a visual meter for the 3.5001–4.0000 band, dynamic rating card, Recent Teams table, Match History by year with totals row. |
| `/login`, `DELETE /session` | Email-only sign-in (no passwords). Submit a matching email to get a session. |
| `/users` | Admin CRUD for players. Index/new/edit/update/destroy, admin-only. |

### Data model

| Model | Key columns |
|-------|-------------|
| `User` | `name`, `email` (unique, optional), `admin`, `location`, `ntrp_rating`, `ntrp_rating_date`, `dynamic_rating`, `dynamic_rating_date` |
| `TennisTeam` | `user_id`, `name`, `team_type`, `section`, `gender`, `rating`, `start_date` |
| `TennisStat` | `user_id`, `year`, `matches_total/won/lost`, `sets_total/won/lost`, `games_total/won/lost`, `defaults` |

`User has_many :tennis_teams, :tennis_stats` (both `dependent: :destroy`). `TennisStat` exposes `match_wpct`/`set_wpct`/`game_wpct` helpers (nil when total is 0).

### Seed data
- **Tara Bucci** (admin) — Villanova PA, 4.0 NTRP (as of 12/31/2025), dynamic 3.94 (as of 2/26/2026). Five teams: Quad Squad, Over Served, Tri Me, AGC ACES, Unmatchables. Match stats for 2024–2026; sets/games for 2024–2025 still pending, to be entered from USTA Connect.
- **Jody Staples** — non-admin, no email yet. Email to be added from `/users`.

### Auto-deploy
`.github/workflows/deploy.yml` triggers on push to any `claude/**` branch: SSHes into the droplet, `git fetch && git reset --hard origin/<branch>`, rebuilds the Docker image, restarts the container, and runs `db:migrate && db:seed`. No PR merge needed.

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

## Last Session (2026-02-28)

Built the tennis sandbox on top of the Hello-World Rails app. Commits `520e8e5`..`68589da`:

1. **Infra.** Fixed the deploy script (`set -e`, auto-clone if `/root/app` missing, quoted `RAILS_MASTER_KEY`). Made the deploy workflow auto-trigger on any `claude/**` push and run `db:migrate`/`db:seed` after each deploy.
2. **Tennis homepage.** Dark-green court theme, animated tennis ball, Sabalenka quote. Replaced emoji card icons with inline SVGs (trophy / bar chart / people). Wired up server-side random quote rotation from a 10-quote pool.
3. **Site restructure.** Root `/` became the Tara's Sandbox landing with sub-app cards; the tennis page moved to `/tennis`.
4. **Auth & users.** Email-only login (no passwords), `User` model with `admin` flag, Tara seeded as admin. `/users` admin CRUD; nav shows current user + Sign In/Out + Players link for admins.
5. **Access control.** Unauthenticated → `/login`; non-admins → `/tennis`. Admin-only nav items (Project 2 placeholder) are shown only to admins.
6. **Player profile.** `/profile` with NTRP rating meter, dynamic rating card, Recent Teams table, Match History by year with a totals row. New `TennisTeam` and `TennisStat` models; the nav user-name is now a link to the profile.

### Open ideas (from last session, not yet built)

- **League tabs on profile.** Replace the flat Recent Teams list with tabs grouped by league. Hovering a league name should reveal a dropdown of the teams in that league.

### Session note
The session ended prematurely due to repeated "Authentication error · This may be a temporary network issue" messages in Claude Code itself — not an app error. The deployed app was fine.

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
