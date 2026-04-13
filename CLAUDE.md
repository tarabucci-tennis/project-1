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

## Current Work

> **Update this section at the end of every session** so the next session can pick up cleanly. Claude should read this first when asked "where did we leave off?".

**Active branch:** `claude/review-progress-notes-66FMD`

**Last completed commit:** `68589da` — Add tennis player profile page with NTRP stats

**In progress:** Captains page with copy/paste roster import.
- Goal: let a team captain paste a roster (from email, spreadsheet, etc.) into a textarea and have the app parse it into player records.
- Status as of 2026-04-13: **no code committed yet.** User reported working on it, but nothing by that name exists in the repo on any branch or stash. Likely lost / never committed, or was in a different session.
- Open questions before resuming:
  - What's the expected paste format? (one player per line? CSV? `Name <email>`?)
  - Does it create new `User` records or a new `Player`/`RosterEntry` model?
  - Which team does the roster belong to — is there a `Team` model yet?

**Next session should:** confirm the above with the user before writing code.

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
