@echo off
setlocal enabledelayedexpansion
if not exist .env (
  echo .env not found. Copy .env.example to .env and update values.
  exit /b 1
)
for /f "usebackq tokens=1* delims==" %%A in (`findstr /b "FIREBASE_PROJECT=" .env`) do set "project=%%B"

flutter pub get
flutter build web --release

if defined project (
  firebase deploy --only hosting --project %project%
) else (
  firebase deploy --only hosting
)

echo Firebase hosting deploy complete.
