$ErrorActionPreference = "Stop"

$flutterApp = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $flutterApp

Write-Host "LexiLingo Android clean runner" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"

# Keep pub sources and the Android project on the same Windows drive.
# This avoids Kotlin's different-roots incremental-cache failure when the
# default PUB_CACHE lives under C:\Users while the repository lives on D:.
$env:PUB_CACHE = Join-Path $repoRoot ".pub-cache"
Write-Host "PUB_CACHE: $env:PUB_CACHE"

Set-Location (Join-Path $flutterApp "android")
try {
    & .\gradlew --stop
} catch {
    Write-Host "No active Gradle daemon to stop." -ForegroundColor DarkGray
}

Set-Location $flutterApp

$paths = @(
    (Join-Path $flutterApp "build"),
    (Join-Path $flutterApp ".dart_tool"),
    (Join-Path $flutterApp "android\.gradle")
)

foreach ($path in $paths) {
    if (Test-Path $path) {
        Write-Host "Removing $path"
        Remove-Item -Recurse -Force $path
    }
}

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
