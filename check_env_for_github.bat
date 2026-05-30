@echo off
setlocal

git ls-files --error-unmatch .env >nul 2>&1
if %errorlevel%==0 (
  echo ERROR: .env is tracked by git. Remove it with:
  echo git rm --cached .env
  exit /b 1
)

echo OK: .env is not tracked by git.
