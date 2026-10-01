param(
  [string]$ProjectDir = "."
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectDir

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not on PATH."
}

flutter create --platforms=android --org com.bant.app .
flutter pub get

Write-Host ""
Write-Host "Android shell created for BANT Flutter."
Write-Host "Next:"
Write-Host "1. Add bant://auth-callback to Supabase redirect URLs."
Write-Host "2. Run with SUPABASE_URL and SUPABASE_ANON_KEY dart-defines."
Write-Host "3. Deploy mobile-api and mobile-livekit-token Edge Functions."
