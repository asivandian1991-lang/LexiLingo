$ErrorActionPreference = "Stop"

$flutterApp = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $flutterApp

Write-Host "LexiLingo Android clean runner" -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"

# Keep pub sources and the Android project on the same Windows drive.
$env:PUB_CACHE = Join-Path $repoRoot ".pub-cache"
Write-Host "PUB_CACHE: $env:PUB_CACHE"

Set-Location (Join-Path $flutterApp "android")
try {
    & .\gradlew --stop
} catch {
    Write-Host "No active Gradle daemon to stop." -ForegroundColor DarkGray
}

Set-Location $flutterApp

# Let Flutter remove generated files first.
Write-Host "Running flutter clean..."
& flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter clean returned code $LASTEXITCODE; continuing with hard cleanup." -ForegroundColor Yellow
}

# Windows PowerShell Remove-Item can fail on deep/vanishing Android build paths.
# Use cmd.exe rd instead; it is much more reliable for Gradle/Firebase output.
$paths = @(
    (Join-Path $flutterApp "build"),
    (Join-Path $flutterApp ".dart_tool"),
    (Join-Path $flutterApp "android\.gradle"),
    (Join-Path $repoRoot ".pub-cache\hosted\pub.dev\flutter_soloud-3.5.4")
)

foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        Write-Host "Removing $path"
        cmd.exe /d /c "rd /s /q \"$path\"" | Out-Null
        if (Test-Path -LiteralPath $path) {
            Write-Host "Warning: could not completely remove $path; continuing." -ForegroundColor Yellow
        }
    }
}

Write-Host "Resolving packages..."
& flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Detected devices:"
& flutter devices

Write-Host "Starting Android app..."
& flutter run
exit $LASTEXITCODE
