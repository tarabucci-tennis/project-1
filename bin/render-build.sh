#!/usr/bin/env bash
# Render build script — runs on every deploy
set -o errexit

# Allow lock file update for new gems (pg added for Render)
export BUNDLE_FROZEN=false
bundle config set --local without 'development test'
bundle install

# Precompile assets
bundle exec rails assets:precompile

# Run database migrations and seeds
bundle exec rails db:migrate
bundle exec rails db:seed
