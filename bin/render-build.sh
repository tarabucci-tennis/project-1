#!/usr/bin/env bash
# Render build script — runs on every deploy
set -o errexit

# Allow lock file update for new gems (pg, bcrypt added for Render)
export BUNDLE_FROZEN=false
bundle config set --local without 'development test'
bundle lock --add-platform x86_64-linux 2>/dev/null || true
bundle install

# Precompile assets
bundle exec rails assets:precompile

# Run database migrations and seeds
bundle exec rails db:migrate
bundle exec rails db:seed
