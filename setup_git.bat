@echo off
if "%~1"=="" (
  echo Usage: setup_git.bat ^<github-username^>
  exit /b 1
)
set "USERNAME=%~1"
set "REPO_URL=https://github.com/%USERNAME%/accounting.git"

if not exist .git (
  git init
)

git add .
rem commit may fail if no changes
git commit -m "Initial commit for accounting Flutter web" 2>nul
git branch -M main
git remote remove origin 2>nul
git remote add origin "%REPO_URL"
git push -u origin main

echo Repository pushed to %REPO_URL
