$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Write-Host "=== Flutter Web Build + Firebase Deploy ===" -ForegroundColor Cyan

# 1. ກວດ Flutter ມີຫຼືບໍ່
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Flutter not found. Please install Flutter and add to PATH." -ForegroundColor Red
    exit 1
}

# 2. ກວດ firebase CLI ມີຫຼືບໍ່
if (-not (Get-Command firebase -ErrorAction SilentlyContinue) -and
    -not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Firebase CLI not found. Run: npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# 3. flutter pub get
Write-Host "`n[1/3] Running flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

# 4. Build release
Write-Host "`n[2/3] Building Flutter web (release)..." -ForegroundColor Yellow
flutter build web --release --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed." }

# 5. Deploy
Write-Host "`n[3/3] Deploying to Firebase Hosting..." -ForegroundColor Yellow
# ລອງ firebase ໂດຍກົງກ່ອນ, ຖ້າຫາກໍ່ install ໄວ້ global
if (Get-Command firebase -ErrorAction SilentlyContinue) {
    firebase deploy --only hosting
} else {
    npx firebase-tools deploy --only hosting
}
if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed." }

Write-Host "`n=== Deployment completed successfully! ===" -ForegroundColor Green