# One-time setup for Windows (PowerShell). Usage:  .\tool\bootstrap.ps1 -Org com.yourorg
param([string]$Org = "com.yourorg")
$ErrorActionPreference = "Stop"

flutter create --org $Org --project-name finance_tracker --platforms android,ios .
flutter pub get

# Remove the default counter-app test; it references a MyApp class we do not have.
Remove-Item -Force -ErrorAction SilentlyContinue test/widget_test.dart

$pkg = "$Org.finance_tracker"
$dir = "android/app/src/main/kotlin/" + ($Org -replace '\.', '/') + "/finance_tracker"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding($false)
$kt = (Get-Content tool/android/MainActivity.kt -Raw) -replace '__PKG__', $pkg
[IO.File]::WriteAllText((Join-Path (Get-Location) "$dir/MainActivity.kt"), $kt, $utf8)

$manifestPath = Join-Path (Get-Location) "android/app/src/main/AndroidManifest.xml"
$manifest = [IO.File]::ReadAllText($manifestPath)
if ($manifest -notmatch "READ_SMS") {
  $perms = @"
<uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.RECEIVE_SMS"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <application
"@
  $manifest = ([regex]'<application').Replace($manifest, $perms.TrimEnd(), 1)
  [IO.File]::WriteAllText($manifestPath, $manifest, $utf8)
}

& "$PSScriptRoot/apply_android_patches.ps1"

# iOS Face ID usage string can't be added on Windows; the CI/mac step or manual edit handles it:
Write-Host "NOTE: add NSFaceIDUsageDescription to ios/Runner/Info.plist (see README)."
Write-Host "Done. Commit android/ and ios/ so CI can build them."
