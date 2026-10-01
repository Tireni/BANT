param(
  [string]$ProjectDir = "."
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectDir

Write-Host "Stopping Gradle daemons..."
if (Test-Path "android\gradlew.bat") {
  Push-Location android
  .\gradlew.bat --stop
  Pop-Location
}

Write-Host "Removing the broken AndroidX annotation cache entry..."
$annotationCache = Join-Path $env:USERPROFILE ".gradle\caches\modules-2\files-2.1\androidx.annotation\annotation-jvm\1.8.2"
if (Test-Path $annotationCache) {
  Remove-Item -Recurse -Force $annotationCache
}

Write-Host "Cleaning Flutter build output..."
flutter clean

Write-Host "Restoring Flutter packages..."
flutter pub get

Write-Host "Refreshing Gradle dependencies and rebuilding..."
Push-Location android
.\gradlew.bat clean --refresh-dependencies
.\gradlew.bat assembleDebug --refresh-dependencies
Pop-Location

Write-Host ""
Write-Host "Gradle dependency repair completed."
Write-Host "You can now run flutter run with your Supabase dart-defines."
