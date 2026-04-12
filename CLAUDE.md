# Project Configuration

## App Specification

**Framework:** Ruby on Rails 8.1.2
**Ruby:** 3.3.6
**Database:** SQLite (multi-database: primary, cache, queue, cable)
**Asset pipeline:** Propshaft
**Background jobs:** Solid Queue (running inside Puma via `SOLID_QUEUE_IN_PUMA`)
**WebSockets:** Solid Cable
**JavaScript:** Import Maps + Stimulus + Turbo (Hotwire)
**Web server:** Puma via Thruster (handles HTTP compression/caching/SSL)
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
| Firewall | Ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) open |
| Container Registry | `registry.digitalocean.com/tarabucci-tennis` |
| SSH Key ID | `54458995` (name: `do-deploy`) |

**App URL:** https://yourcourtreport.com
**Domain:** yourcourtreport.com (with www redirect)
**SSL:** Auto-provisioned via Thruster + Let's Encrypt

### Deployment Method

The app is deployed via Docker on a DigitalOcean Droplet. On first boot, a cloud-init user-data script:
1. Clones the repo from `https://github.com/tarabucci-tennis/project-1`
2. Runs `docker build -t project-1 .`
3. Starts the container: `docker run -d -p 80:80 -p 443:443 -e RAILS_MASTER_KEY=... -e TLS_DOMAIN=yourcourtreport.com,www.yourcourtreport.com -v /root/storage:/rails/storage -v /root/thruster-storage:/rails/.thruster --restart unless-stopped project-1`

Thruster automatically provisions Let's Encrypt SSL certificates when the `TLS_DOMAIN` environment variable is set.

SQLite databases are persisted via a Docker volume mounted at `/root/storage` on the host.
Thruster's SSL certificates are persisted via a Docker volume mounted at `/root/thruster-storage`.

### Auto-Deploy (GitHub Actions)

Deployments are automated via GitHub Actions (`.github/workflows/deploy.yml`).

**Trigger:** Any push to `main` or `claude/**` branches automatically deploys.

**How it works:**
1. GitHub Actions SSHes into the Droplet using the `deploy_key` SSH key
2. Pulls the latest code from the pushed branch
3. Builds a new Docker image
4. Stops and removes the old container
5. Starts a new container with SSL, volumes, and environment variables
6. Runs `db:migrate` and `db:seed`

**Required GitHub Secrets** (already configured):
- `DEPLOY_HOST` — Droplet IP (`146.190.112.29`)
- `DEPLOY_SSH_KEY` — Private key matching `~/.ssh/deploy_key` on the Droplet
- `RAILS_MASTER_KEY` — Rails credentials master key

**To deploy:** Just merge a PR to `main`. No manual steps needed.

### Manual Re-deploy (fallback)

If GitHub Actions fails, SSH into the droplet and run:
```bash
cd /root/app && git pull && docker build -t project-1 . && docker stop project-1 && docker rm project-1 && docker run -d -p 80:80 -p 443:443 -e RAILS_MASTER_KEY=$(cat /root/app/config/master.key) -e TLS_DOMAIN=yourcourtreport.com,www.yourcourtreport.com -v /root/storage:/rails/storage -v /root/thruster-storage:/rails/.thruster --name project-1 --restart unless-stopped project-1
```

## GitHub

Repo: `tarabucci-tennis/project-1` (public)
Default branch: `main`

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
