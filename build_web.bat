@echo off
setlocal enabledelayedexpansion
if not exist .env (
  echo .env not found. Copy .env.example to .env and update values.
  exit /b 1
)

flutter pub get
flutter build web --release

echo Flutter web release build complete.
