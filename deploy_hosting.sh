#!/usr/bin/env bash
set -e

if [ ! -f .env ]; then
  echo ".env not found. Copy .env.example to .env and update values."
  exit 1
fi

PROJECT=$(grep '^FIREBASE_PROJECT=' .env | cut -d'=' -f2- | tr -d '\r')

flutter pub get
flutter build web --release

if [ -n "$PROJECT" ]; then
  firebase deploy --only hosting --project "$PROJECT"
else
  firebase deploy --only hosting
fi

echo "Firebase hosting deploy complete."
