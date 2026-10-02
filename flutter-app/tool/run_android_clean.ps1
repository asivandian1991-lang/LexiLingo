$ErrorActionPreference = "Stop"

$flutterApp = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $flutterApp

Write-Host "Quoriv AI Android runner" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"

# Keep Pub cache on the same drive as the project to avoid Kotlin cross-drive
# cache issues on Windows. This only changes the cache location for this process.
$env:PUB_CACHE = Join-Path $repoRoot ".pub-cache"
Write-Host "PUB_CACHE: $env:PUB_CACHE"

Set-Location $flutterApp

Write-Host "Stopping Gradle daemons..."
try {
    Push-Location (Join-Path $flutterApp "android")
    & .\gradlew --stop
} catch {
    Write-Host "No active Gradle daemon to stop." -ForegroundColor DarkGray
} finally {
    Pop-Location
}

Set-Location $flutterApp

# Use Flutter's own cleanup only. Do not recursively delete arbitrary paths.
Write-Host "Running flutter clean..."
& flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Resolving packages..."
& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Detected devices:"
& flutter devices

Write-Host "Starting Android app..."
& flutter run
exit $LASTEXITCODE
