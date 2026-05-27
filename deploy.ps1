$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "Building Flutter web app..."
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed."
}

Write-Host "Deploying to Firebase Hosting..."
npx firebase deploy
if ($LASTEXITCODE -ne 0) {
    throw "Firebase deploy failed."
}

Write-Host "Deployment completed successfully."
