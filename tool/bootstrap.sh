#!/usr/bin/env bash
# One-time setup: generates android/ and ios/, then applies SMS + biometric config.
set -euo pipefail
ORG="${ORG:-com.yourorg}"
flutter create --org "$ORG" --project-name finance_tracker --platforms android,ios .
flutter pub get

PKG="$ORG.finance_tracker"
DIR="android/app/src/main/kotlin/$(echo "$ORG" | tr . /)/finance_tracker"
mkdir -p "$DIR"
sed "s/__PKG__/$PKG/" tool/android/MainActivity.kt > "$DIR/MainActivity.kt"

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q READ_SMS "$MANIFEST"; then
  sed -i.bak '0,/<application/s//<uses-permission android:name="android.permission.READ_SMS"\/>\n    <uses-permission android:name="android.permission.RECEIVE_SMS"\/>\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"\/>\n    <application/' "$MANIFEST" && rm -f "$MANIFEST.bak"
fi

PLIST=ios/Runner/Info.plist
if [[ "$(uname)" == "Darwin" ]] && ! grep -q NSFaceIDUsageDescription "$PLIST"; then
  /usr/libexec/PlistBuddy -c "Add :NSFaceIDUsageDescription string 'Unlock the app with Face ID'" "$PLIST"
fi
echo "Done. Commit android/ and ios/ so CI can build them."
