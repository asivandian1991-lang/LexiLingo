$ErrorActionPreference = "Stop"

$flutterApp = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $flutterApp

Write-Host "LexiLingo Android clean runner" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"

# Keep Pub cache on the same drive as the project to avoid Kotlin cross-drive
# incremental cache errors on Windows.
$env:PUB_CACHE = Join-Path $repoRoot ".pub-cache"
Write-Host "PUB_CACHE: $env:PUB_CACHE"

# Stop Gradle cleanly.
Set-Location (Join-Path $flutterApp "android")
try {
    & .\gradlew --stop
} catch {
    Write-Host "No active Gradle daemon to stop." -ForegroundColor DarkGray
}

# Always return to the Flutter project root before running Flutter commands.
Set-Location $flutterApp

Write-Host "Running flutter clean..."
& flutter clean
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Only remove the obsolete flutter_soloud cache folder if it exists.
# Do NOT recursively delete android/.gradle with cmd.exe; malformed quoting on
# Windows can escape to the drive root.
$obsoleteSoLoud = Join-Path $env:PUB_CACHE "hosted\pub.dev\flutter_soloud-3.5.4"
if (Test-Path -LiteralPath $obsoleteSoLoud) {
    Write-Host "Removing obsolete flutter_soloud cache..."
    try {
        [System.IO.Directory]::Delete($obsoleteSoLoud, $true)
    } catch {
        Write-Host "Could not fully remove obsolete flutter_soloud cache; continuing." -ForegroundColor Yellow
    }
}

# Make absolutely sure the current directory is the Flutter app.
Set-Location $flutterApp

Write-Host "Resolving packages..."
& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Detected devices:"
& flutter devices

Write-Host "Starting Android app..."
& flutter run
exit $LASTEXITCODE
