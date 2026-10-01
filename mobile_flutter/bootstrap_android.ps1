param(
  [string]$ProjectDir = "."
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectDir

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not on PATH."
}

Write-Host "Creating/verifying the Android platform shell..."
flutter create --platforms=android --org com.bant.app --project-name bant_mobile .

$manifest = "android/app/src/main/AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
  throw "AndroidManifest.xml was not generated."
}

$xml = Get-Content $manifest -Raw

if ($xml -notmatch 'android.permission.RECORD_AUDIO') {
  $xml = $xml -replace '<manifest xmlns:android="http://schemas.android.com/apk/res/android">', @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
'@
}

if ($xml -notmatch 'android:scheme="bant"') {
  $intent = @'
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="bant" android:host="auth-callback"/>
            </intent-filter>
'@
  $xml = $xml -replace '</activity>', ($intent + '        </activity>')
}

Set-Content -Path $manifest -Value $xml -Encoding UTF8

$widgetTest = @'
import 'package:flutter_test/flutter_test.dart';
import 'package:bant_mobile/main.dart';

void main() {
  testWidgets('BANT app class is available', (WidgetTester tester) async {
    expect(const BantMobileApp(), isNotNull);
  });
}
'@
New-Item -ItemType Directory -Force -Path "test" | Out-Null
Set-Content -Path "test/widget_test.dart" -Value $widgetTest -Encoding UTF8

flutter pub get
flutter analyze

Write-Host ""
Write-Host "BANT Android foundation is ready."
Write-Host "Supabase redirect URL required: bant://auth-callback"
Write-Host ""
Write-Host "Run:"
Write-Host 'flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY'
