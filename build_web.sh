#!/usr/bin/env bash
set -e

if [ ! -f .env ]; then
  echo ".env not found. Copy .env.example to .env and update values."
  exit 1
fi

flutter pub get
flutter build web --release

echo "Flutter web release build complete."
