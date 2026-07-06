# Run this script to set up the Flutter project
Write-Host "Installing Flutter SDK via winget..." -ForegroundColor Cyan
winget install Google.FlutterSDK 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Download Flutter from https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    Write-Host "Then run: flutter create ." -ForegroundColor Yellow
    exit 1
}

# Add to PATH for this session
$env:Path += ";$env:USERPROFILE\AppData\Local\Flutter\bin"

# Generate platform files
Write-Host "Creating platform files..." -ForegroundColor Cyan
flutter create --project-name personal_app . 2>$null

Write-Host "Installing dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "Run 'flutter run' to start the app" -ForegroundColor Green
