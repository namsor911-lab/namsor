#!/usr/bin/env bash
set -e

if [ "$#" -ne 1 ]; then
  echo "Usage: ./setup_git.sh <github-username>"
  exit 1
fi

USERNAME="$1"
REPO_URL="https://github.com/$USERNAME/accounting.git"

if [ ! -d .git ]; then
  git init
fi

git add .
git commit -m "Initial commit for accounting Flutter web" || true
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"
git push -u origin main

echo "Repository pushed to $REPO_URL"
