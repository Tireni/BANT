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

$requiredPermissions = @(
  '<uses-permission android:name="android.permission.INTERNET"/>',
  '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>',
  '<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE"/>',
  '<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>',
  '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
  '<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>',
  '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>',
  '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>'
)

foreach ($permission in $requiredPermissions) {
  $permissionName = [regex]::Match($permission, 'android:name="([^"]+)"').Groups[1].Value
  if ($xml -notmatch [regex]::Escape($permissionName)) {
    $xml = $xml -replace '<application', ("    " + $permission + [Environment]::NewLine + "    <application")
  }
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

if ($xml -notmatch 'android:host="invite"') {
  $inviteIntent = @'
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="bant" android:host="invite"/>
            </intent-filter>
'@
  $xml = $xml -replace '</activity>', ($inviteIntent + '        </activity>')
}

if ($xml -notmatch 'android:host="bant-demo.vercel.app"') {
  $webInviteIntent = @'
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="bant-demo.vercel.app" android:pathPrefix="/r/"/>
            </intent-filter>
'@
  $xml = $xml -replace '</activity>', ($webInviteIntent + '        </activity>')
}

if ($xml -notmatch 'flutter_deeplinking_enabled') {
  $xml = $xml -replace '<activity', @'
        <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>
        <activity
'@
}

Set-Content -Path $manifest -Value $xml -Encoding UTF8

$mainActivity = Get-ChildItem -Path "android/app/src/main/kotlin" -Filter "MainActivity.kt" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mainActivity) {
  $mainSource = Get-Content $mainActivity.FullName -Raw
  $packageLine = ($mainSource -split [Environment]::NewLine | Where-Object { $_ -match '^package ' } | Select-Object -First 1)
  if (-not $packageLine) {
    $packageLine = 'package com.bant.app.bant_mobile'
  }

  $mainSource = @"
$packageLine

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bant/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareText") {
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    startActivity(Intent.createChooser(intent, "Share BANT room"))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
"@

  Set-Content -Path $mainActivity.FullName -Value $mainSource -Encoding UTF8
}


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


# Mirror the canonical BANT brand asset from the web app into Flutter.
$brandDir = Join-Path $PSScriptRoot "assets\brand"
New-Item -ItemType Directory -Force -Path $brandDir | Out-Null
$webMascot = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\brand\bant-mascot.png"
$flutterMascot = Join-Path $brandDir "bant-mascot.png"
if (Test-Path $webMascot) {
  Copy-Item $webMascot $flutterMascot -Force
  Write-Host "Copied canonical BANT mascot into Flutter assets."
} else {
  Write-Warning "Canonical BANT mascot was not found at $webMascot"
}
