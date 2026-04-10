#!/usr/bin/env bash
#
# Court Report — Phase 1 Deploy Script
# =====================================
#
# Run this ON THE DIGITALOCEAN SERVER to deploy Phase 1 changes:
#   - New Court Report branding (white/black/gold)
#   - Real team data (Kiss My Ace, Pour Decisions, PCC, Legacy 2)
#   - League category grouping on My Teams
#
# FIRST TIME (to get the script onto the server):
#   ssh root@146.190.112.29
#   cd /root/app
#   git fetch origin claude/fix-teams-500-error-GPgeR
#   git checkout claude/fix-teams-500-error-GPgeR
#   bash bin/deploy-phase-1.sh
#
# EVERY TIME AFTER THAT:
#   ssh root@146.190.112.29
#   bash /root/app/bin/deploy-phase-1.sh
#
# The script will:
#   1. Find your Rails master key automatically
#   2. Pull the latest code from GitHub
#   3. Rebuild the Docker image
#   4. Stop the old container and start the new one
#   5. Apply database updates
#   6. Load the real team data
#
# Safe to re-run. If something fails, it stops and tells you why.

set -euo pipefail

APP_NAME="project-1"
APP_DIR="/root/app"
BRANCH="claude/clarify-team-members-1ycVZ"
IMAGE="project-1"

blue()  { printf "\033[34m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*" >&2; }
step()  { echo; blue "==> $*"; }

# --------------------------------------------------------------
# Sanity check: we must be on the server, not Tara's laptop
# --------------------------------------------------------------
if [ ! -d "$APP_DIR" ]; then
  red "ERROR: This script must run on the DigitalOcean server."
  red "  Directory $APP_DIR does not exist here."
  red ""
  red "  Connect to the server first with:"
  red "    ssh root@146.190.112.29"
  exit 1
fi

cd "$APP_DIR"

# --------------------------------------------------------------
# Step 1: Find the Rails master key
# --------------------------------------------------------------
step "Step 1/7: Finding Rails master key..."

RAILS_MASTER_KEY=""

# Try the currently running container first (works if the app is running)
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${APP_NAME}\$"; then
  RAILS_MASTER_KEY="$(docker exec "$APP_NAME" env 2>/dev/null | grep '^RAILS_MASTER_KEY=' | cut -d= -f2- || true)"
fi

# Try the standard Rails location
if [ -z "$RAILS_MASTER_KEY" ] && [ -f "$APP_DIR/config/master.key" ]; then
  RAILS_MASTER_KEY="$(cat "$APP_DIR/config/master.key")"
fi

# Try a cached copy from a previous deploy
if [ -z "$RAILS_MASTER_KEY" ] && [ -f "/root/.rails_master_key" ]; then
  RAILS_MASTER_KEY="$(cat /root/.rails_master_key)"
fi

if [ -z "$RAILS_MASTER_KEY" ]; then
  red "ERROR: Could not find RAILS_MASTER_KEY."
  red ""
  red "  Looked in:"
  red "    - Running container's environment"
  red "    - $APP_DIR/config/master.key"
  red "    - /root/.rails_master_key"
  red ""
  red "  Fix: save your master key to /root/.rails_master_key and re-run."
  red "    echo 'your-master-key-here' > /root/.rails_master_key"
  red "    chmod 600 /root/.rails_master_key"
  exit 1
fi

# Cache it for next time
if [ ! -f "/root/.rails_master_key" ]; then
  printf "%s" "$RAILS_MASTER_KEY" > /root/.rails_master_key
  chmod 600 /root/.rails_master_key
  green "  Cached master key to /root/.rails_master_key for future runs."
fi

green "  Found master key."

# --------------------------------------------------------------
# Step 2: Pull the latest code
# --------------------------------------------------------------
step "Step 2/7: Pulling latest code from GitHub ($BRANCH)..."

git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull origin "$BRANCH"

green "  Code updated. Latest commit:"
git log -1 --oneline | sed 's/^/    /'

# --------------------------------------------------------------
# Step 3: Build the Docker image
# --------------------------------------------------------------
step "Step 3/7: Building Docker image (takes 2-5 minutes)..."

docker build -t "$IMAGE" .

green "  Image built."

# --------------------------------------------------------------
# Step 4: Stop and remove the old container
# --------------------------------------------------------------
step "Step 4/7: Stopping old container..."

if docker ps --format '{{.Names}}' | grep -q "^${APP_NAME}\$"; then
  docker stop "$APP_NAME" >/dev/null
  green "  Old container stopped."
else
  echo "  No running container named $APP_NAME."
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}\$"; then
  docker rm "$APP_NAME" >/dev/null
  green "  Old container removed."
fi

# --------------------------------------------------------------
# Step 5: Start the new container
# --------------------------------------------------------------
step "Step 5/7: Starting new container..."

docker run -d \
  -p 80:80 \
  -e RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  -v /root/storage:/rails/storage \
  --name "$APP_NAME" \
  --restart unless-stopped \
  "$IMAGE" >/dev/null

green "  New container started."

echo "  Waiting 5 seconds for the app to boot..."
sleep 5

# --------------------------------------------------------------
# Step 6: Run database migrations
# --------------------------------------------------------------
step "Step 6/7: Applying database updates..."

docker exec "$APP_NAME" bin/rails db:migrate

green "  Database updated."

# --------------------------------------------------------------
# Step 7: Seed real team data
# --------------------------------------------------------------
step "Step 7/7: Loading real team data..."

docker exec "$APP_NAME" bin/rails db:seed

green "  Real team data loaded."

# --------------------------------------------------------------
# Done!
# --------------------------------------------------------------
echo
green "════════════════════════════════════════════════════════"
green "  DEPLOY COMPLETE!"
green "════════════════════════════════════════════════════════"
echo
echo "  Visit:         http://146.190.112.29"
echo "  Sign in as:    tarabucci@gmail.com"
echo
echo "  You should see:"
echo "    - Black header with gold COURT REPORT logo"
echo "    - My Teams page with 4 teams under USTA/Inter-Club/Local"
echo "    - Click Kiss My Ace: April 14 match + 22 players"
echo
echo "  If something looks wrong, take a screenshot and show Claude."
echo
