#!/bin/bash
# Force deploy — pull latest main, rebuild image, restart container,
# run db:migrate. Unlike bin/auto-deploy.sh this has no "no new
# commits" short-circuit so it ALWAYS does a full rebuild.
#
# IMPORTANT: This script does NOT run db:seed. The seed file is
# destructive — it wipes every team_membership for your four teams
# and recreates them from scratch, which would blow away every real
# teammate's join. If you need to reset the seeded data, run
# `bash /root/app/bin/seed.sh` manually.
#
# Usage on the droplet:
#   bash /root/app/bin/force-deploy.sh

set -e

APP_DIR="/root/app"
LOG_PREFIX="[$(date '+%H:%M:%S')]"

cd "$APP_DIR"

echo "$LOG_PREFIX Pulling latest main from GitHub..."
git fetch origin main --quiet
git checkout main 2>&1 || true
git reset --hard origin/main
echo "$LOG_PREFIX Now at: $(git rev-parse --short HEAD) $(git log -1 --pretty=%s)"

MASTER_KEY=$(cat "$APP_DIR/config/master.key" | tr -d '[:space:]')
if [ -z "$MASTER_KEY" ]; then
  echo "$LOG_PREFIX ERROR: master.key is empty or missing. Aborting."
  exit 1
fi

echo "$LOG_PREFIX Building Docker image..."
docker build -t project-1 .

echo "$LOG_PREFIX Stopping old container..."
docker stop project-1 >/dev/null 2>&1 || true
docker rm   project-1 >/dev/null 2>&1 || true

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

sleep 5

if ! docker ps --filter "name=project-1" --filter "status=running" --format '{{.Names}}' | grep -q "project-1"; then
  echo "$LOG_PREFIX ERROR: Container failed to start. Check: docker logs project-1"
  exit 1
fi

echo "$LOG_PREFIX Running migrations (seeds intentionally skipped)..."
docker exec project-1 bin/rails db:migrate

echo "$LOG_PREFIX =============================="
echo "$LOG_PREFIX DEPLOY COMPLETE"
echo "$LOG_PREFIX (To reseed sample data, run: bash /root/app/bin/seed.sh)"
echo "$LOG_PREFIX =============================="
