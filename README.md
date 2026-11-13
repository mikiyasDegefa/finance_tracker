# Finance Tracker (Flutter · Android + iOS)

Local-first, encrypted transaction tracker.

## What works now (v0.2)
PIN lock with lockout + optional biometrics, SQLCipher-encrypted database (key in Keystore/Keychain),
multiple workspaces (isolated queries), accounts with calculated balances, configured SMS senders,
Android SMS fetch (configured senders only), paste-SMS (works on iOS too), template-based parser with
tester, manual/hybrid/automatic processing, review screen, duplicate prevention (SMS hash + reference),
manual transactions, edit/delete with audit trail, dashboard.

**Not built yet:** backup/restore, cloud sync, budgets/goals, double-entry ledger, transfers,
incoming-SMS receiver/WorkManager, PIN change.

**Existing repo?** After pulling this version run `.\tool\apply_android_patches.ps1`.
Templates are samples: tune regexes with real (anonymised) SMS from your banks.

## Platform behaviour
| Capability | Android | iOS |
|---|---|---|
| SMS collection | Yes (`READ_SMS`, configured senders only) | Not possible: iOS blocks inbox access. Uses manual entry/import via `UnsupportedSmsGateway` |
| PIN + biometrics | Yes | Yes (Face ID / Touch ID) |
| Encrypted SQLite | SQLCipher | SQLCipher |

All SMS access sits behind `SmsGateway`, so parsing, ledger and UI code is shared.

## First-time setup
**Windows (PowerShell):**
```powershell
.\tool\bootstrap.ps1 -Org com.yourorg
git init; git add .; git commit -m "Bootstrap"
git branch -M main
git remote add origin https://github.com/<you>/finance_tracker.git
git push -u origin main
```
If scripts are blocked: `Set-ExecutionPolicy -Scope Process Bypass`.

**macOS/Linux/Git Bash:** `ORG=com.yourorg ./tool/bootstrap.sh`

**Face ID (iOS):** add this inside the root `<dict>` of `ios/Runner/Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key><string>Unlock the app with Face ID</string>
```

You can't run or sign iOS builds on Windows; GitHub's macOS runner does that.
Android can be run locally (`flutter run` with a device/emulator).
Replace `com.yourorg` with your real org. For signed iOS builds copy
`ios_ExportOptions.plist.template` to `ios/ExportOptions.plist` and fill it in.

## Workflows (.github/workflows)
- **ci.yml**: format, analyze, test on every push/PR.
- **android.yml**: tag `v*` or manual run produces split APKs + AAB.
- **ios.yml**: tag `v*` or manual run does an unsigned compile check; tick `signed` for an IPA. Set repo variable `UPLOAD_TESTFLIGHT=true` to auto-upload.

Release: `git tag v0.1.0 && git push --tags`

## Secrets (Settings > Secrets and variables > Actions)
Android (optional, for Play signing): `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
(`base64 -w0 upload-keystore.jks`). Add the standard `key.properties` signing block to `android/app/build.gradle(.kts)` per Flutter's "Sign the app" docs.

iOS (signed): `IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`; TestFlight: `APPSTORE_API_KEY_P8_BASE64`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`. Needs an Apple Developer account.

## Notes
- Google Play restricts `READ_SMS`; submit the Permissions Declaration form or distribute outside Play.
- Android channel code: `tool/android/MainActivity.kt` (copied in by bootstrap).
- Next: Drift schema + SQLCipher, PIN/biometric, workspaces, parser module.
