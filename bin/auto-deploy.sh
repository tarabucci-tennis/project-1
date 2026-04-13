#!/bin/bash
# Auto-deploy script for Court Report
# This runs on the DigitalOcean droplet via cron.
# It checks if main has new commits; if so, rebuilds and restarts the container.
#
# One-time setup on the droplet:
#   chmod +x /root/app/bin/auto-deploy.sh
#   (crontab -l 2>/dev/null; echo "*/2 * * * * /root/app/bin/auto-deploy.sh >> /var/log/court-report-deploy.log 2>&1") | crontab -
#
# After that, every push to main on GitHub auto-deploys within 2 minutes.
# No SSH keys, no GitHub secrets, no terminal commands needed ever again.

set -e

APP_DIR="/root/app"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

cd "$APP_DIR"

# Fetch the latest from origin
git fetch origin main --quiet

# Compare local HEAD to origin/main
LOCAL=$(git rev-parse main 2>/dev/null || git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
  # No new commits — exit silently
  exit 0
fi

echo "$LOG_PREFIX New commits detected. Deploying..."
echo "$LOG_PREFIX Local:  $LOCAL"
echo "$LOG_PREFIX Remote: $REMOTE"

# Reset to the new main
git checkout main 2>&1 || true
git reset --hard origin/main

# Read the master key
MASTER_KEY=$(cat "$APP_DIR/config/master.key" | tr -d '[:space:]')

if [ -z "$MASTER_KEY" ]; then
  echo "$LOG_PREFIX ERROR: master.key is empty or missing. Aborting."
  exit 1
fi

# Build the new image
echo "$LOG_PREFIX Building Docker image..."
docker build -t project-1 . || { echo "$LOG_PREFIX ERROR: docker build failed"; exit 1; }

# Stop and remove the old container (ignore errors if it doesn't exist)
echo "$LOG_PREFIX Stopping old container..."
docker stop project-1 >/dev/null 2>&1 || true
docker rm project-1 >/dev/null 2>&1 || true

# Start the new container with SSL
echo "$LOG_PREFIX Starting new container..."
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -e "RAILS_MASTER_KEY=$MASTER_KEY" \
  -e "TLS_DOMAIN=yourcourtreport.com,www.yourcourtreport.com" \
  -v /root/storage:/rails/storage \
  -v /root/thruster-storage:/rails/.thruster \
  --name project-1 \
  --restart unless-stopped \
  project-1

# Wait a moment and verify it's running
sleep 5

if docker ps --filter "name=project-1" --filter "status=running" --format '{{.Names}}' | grep -q "project-1"; then
  echo "$LOG_PREFIX Container is running. Applying database migrations and seeds..."
  # Run migrations and seeds inside the running container. Seeds are idempotent —
  # they find_or_create_by! most records and destroy_all + recreate for the Apr 14
  # lineup. Safe to run on every deploy.
  if docker exec project-1 bin/rails db:migrate db:seed; then
    echo "$LOG_PREFIX Migrations and seeds applied."
    echo "$LOG_PREFIX Deploy successful."
  else
    echo "$LOG_PREFIX ERROR: db:migrate or db:seed failed. Check: docker logs project-1"
    exit 1
  fi
else
  echo "$LOG_PREFIX ERROR: Container is NOT running after deploy. Check: docker logs project-1"
  exit 1
fi
