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


$settingsGradle = "android/settings.gradle.kts"
if (Test-Path $settingsGradle) {
  $settingsText = Get-Content $settingsGradle -Raw
  if ($settingsText -notmatch 'com.google.gms.google-services') {
    $settingsText = $settingsText -replace 'plugins \{', @'
plugins {
    id("com.google.gms.google-services") version "4.5.0" apply false
'@
    Set-Content -Path $settingsGradle -Value $settingsText -Encoding UTF8
  }
}

$appGradle = "android/app/build.gradle.kts"
if (Test-Path $appGradle) {
  $appText = Get-Content $appGradle -Raw

  if ($appText -notmatch 'id\("com.google.gms.google-services"\)') {
    $appText = $appText -replace 'plugins \{', @'
plugins {
    id("com.google.gms.google-services")
'@
  }

  if ($appText -notmatch 'isCoreLibraryDesugaringEnabled\s*=\s*true') {
    if ($appText -match 'compileOptions\s*\{') {
      $appText = $appText -replace 'compileOptions\s*\{', @'
compileOptions {
        isCoreLibraryDesugaringEnabled = true
'@
    } else {
      $appText = $appText -replace 'android \{', @'
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
'@
    }
  }

  if ($appText -notmatch 'desugar_jdk_libs') {
    if ($appText -match 'dependencies\s*\{') {
      $appText = $appText -replace 'dependencies\s*\{', @'
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
'@
    } else {
      $appText += @'

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
'@
    }
  }

  Set-Content -Path $appGradle -Value $appText -Encoding UTF8
}


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
  '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
  '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
  '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>',
  '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>',
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


if ($xml -notmatch 'BackgroundAudioService') {
  $backgroundService = @'
        <service
            android:name=".BackgroundAudioService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="microphone|mediaPlayback" />
'@
  $xml = $xml -replace '</application>', ($backgroundService + '    </application>')
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
import androidx.core.content.ContextCompat
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bant/background_audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val microphone = call.argument<Boolean>("microphone") ?: false
                        val serviceIntent = Intent(this, BackgroundAudioService::class.java).apply {
                            putExtra("microphone", microphone)
                        }
                        ContextCompat.startForegroundService(this, serviceIntent)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, BackgroundAudioService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
"@

  Set-Content -Path $mainActivity.FullName -Value $mainSource -Encoding UTF8

  $servicePath = Join-Path $mainActivity.Directory.FullName "BackgroundAudioService.kt"
  $serviceSource = @"
$packageLine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class BackgroundAudioService : Service() {
    companion object {
        private const val CHANNEL_ID = "bant_live_audio"
        private const val NOTIFICATION_ID = 2401
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BANT live audio",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps BANT room audio active while you use other apps."
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val microphone = intent?.getBooleanExtra("microphone", false) == true
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("BANT room is live")
            .setContentText("Your room audio stays connected in the background.")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val type = if (microphone) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            }
            startForeground(NOTIFICATION_ID, notification, type)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
"@
  Set-Content -Path $servicePath -Value $serviceSource -Encoding UTF8
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
