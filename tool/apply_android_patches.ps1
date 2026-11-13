# Run once in an already-bootstrapped repo (Windows PowerShell):
#   .\tool\apply_android_patches.ps1
# - disables Android auto-backup (a restored DB can't be decrypted without the Keystore key)
# - makes the launch theme AppCompat-based (needed by the biometric prompt)
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$m = Join-Path (Get-Location) "android/app/src/main/AndroidManifest.xml"
$x = [IO.File]::ReadAllText($m)
if ($x -match 'android:allowBackup="true"') {
  $x = $x -replace 'android:allowBackup="true"', 'android:allowBackup="false"'
} elseif ($x -notmatch 'android:allowBackup') {
  $x = ([regex]'<application').Replace($x, '<application android:allowBackup="false"', 1)
}
[IO.File]::WriteAllText($m, $x, $utf8)

foreach ($f in "android/app/src/main/res/values/styles.xml", "android/app/src/main/res/values-night/styles.xml") {
  $p = Join-Path (Get-Location) $f
  if (Test-Path $p) {
    $s = [IO.File]::ReadAllText($p)
    $s = $s -replace '@android:style/Theme\.Light\.NoTitleBar', 'Theme.AppCompat.Light.NoActionBar'
    $s = $s -replace '@android:style/Theme\.Black\.NoTitleBar', 'Theme.AppCompat.NoActionBar'
    [IO.File]::WriteAllText($p, $s, $utf8)
  }
}
Write-Host "Android patches applied. Commit the changes."

# Disable AGP "lintVital" tasks: they crash on some JDKs (List.removeLast) and are not needed to build.
$kts = Join-Path (Get-Location) "android/build.gradle.kts"
$groovy = Join-Path (Get-Location) "android/build.gradle"
$marker = "lintVital"
if (Test-Path $kts) {
  $t = [IO.File]::ReadAllText($kts)
  if ($t -notmatch $marker) {
    $t += @"

// Workaround: lintVital crashes on some JDKs and is not needed for our builds.
subprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital")) enabled = false
    }
}
"@
    [IO.File]::WriteAllText($kts, $t, $utf8)
  }
} elseif (Test-Path $groovy) {
  $t = [IO.File]::ReadAllText($groovy)
  if ($t -notmatch $marker) {
    $t += @"

// Workaround: lintVital crashes on some JDKs and is not needed for our builds.
subprojects {
    tasks.configureEach { t ->
        if (t.name.startsWith("lintVital")) { t.enabled = false }
    }
}
"@
    [IO.File]::WriteAllText($groovy, $t, $utf8)
  }
}
Write-Host "Gradle lintVital workaround applied."
