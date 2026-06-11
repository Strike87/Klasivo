#!/bin/bash
# Klasivo Instant GitHub Sync
# Usage: ./git-sync.sh "commit message"
# If no message provided, auto-generates one from changed files

cd /home/z/my-project/klasivo

# Stage all changes
git add -A

# Check if there's anything to commit
if git diff --cached --quiet; then
  echo "✓ Nothing to sync — working tree clean"
  exit 0
fi

# Generate commit message if not provided
if [ -z "$1" ]; then
  CHANGED=$(git diff --cached --name-only | head -5 | tr '\n' ', ' | sed 's/,$//')
  MSG="chore: update ${CHANGED}"
else
  MSG="$1"
fi

# Commit and push
git commit -m "$MSG" && git push origin main

if [ $? -eq 0 ]; then
  echo "✓ Synced to GitHub: $MSG"
else
  echo "✗ Sync failed!"
  exit 1
fi
