#!/bin/bash
set -u

cat <<'BANNER'
========================================================================
PROJECT: Court Report (https://yourcourtreport.com)
NOT "Tara's Sandbox" — that app no longer exists in this repo.
If you see references to "sandbox" or "Tara's Sandbox" in code or
in CLAUDE.md, you are reading OLD code on a stale branch. Stop and
reset to origin/main BEFORE doing any work.
========================================================================
BANNER

cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || { echo "(not a git repo)"; exit 0; }

git fetch origin main --quiet 2>/dev/null || {
  echo "(git fetch origin main failed — skipping branch check)"; exit 0; }

BRANCH=$(git rev-parse --abbrev-ref HEAD)
HEAD_SHA=$(git rev-parse HEAD)
MAIN_SHA=$(git rev-parse origin/main)
MERGE_BASE=$(git merge-base HEAD origin/main 2>/dev/null || echo "")

echo
echo "Branch:      $BRANCH"
echo "HEAD:        $HEAD_SHA"
echo "origin/main: $MAIN_SHA"

if [ "$HEAD_SHA" = "$MAIN_SHA" ]; then
  echo "OK — HEAD is at origin/main."
elif [ "$MERGE_BASE" = "$HEAD_SHA" ]; then
  echo
  echo "!!  STALE BRANCH WARNING  !!"
  echo "HEAD is BEHIND origin/main. You are reading OLD code."
  echo "Run this before doing any work:"
  echo "    git fetch origin main && git reset --hard origin/main"
elif [ "$MERGE_BASE" = "$MAIN_SHA" ]; then
  echo "OK — HEAD is ahead of origin/main (feature work in progress)."
else
  echo "WARNING — HEAD and origin/main have diverged (merge-base $MERGE_BASE)."
fi
exit 0
