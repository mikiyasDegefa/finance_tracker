#!/usr/bin/env bash
# One-time setup: generates android/ and ios/, then applies SMS + biometric config.
set -euo pipefail
ORG="${ORG:-com.yourorg}"
flutter create --org "$ORG" --project-name finance_tracker --platforms android,ios .
flutter pub get

# Remove the default counter-app test; it references a MyApp class we do not have.
rm -f test/widget_test.dart

PKG="$ORG.finance_tracker"
DIR="android/app/src/main/kotlin/$(echo "$ORG" | tr . /)/finance_tracker"
mkdir -p "$DIR"
sed "s/__PKG__/$PKG/" tool/android/MainActivity.kt > "$DIR/MainActivity.kt"

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q READ_SMS "$MANIFEST"; then
  sed -i.bak '0,/<application/s//<uses-permission android:name="android.permission.READ_SMS"\/>\n    <uses-permission android:name="android.permission.RECEIVE_SMS"\/>\n    <uses-permission android:name="android.permission.USE_BIOMETRIC"\/>\n    <application/' "$MANIFEST" && rm -f "$MANIFEST.bak"
fi

sed -i.bak 's/android:allowBackup="true"/android:allowBackup="false"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
grep -q 'android:allowBackup' "$MANIFEST" || { sed -i.bak '0,/<application/s//<application android:allowBackup="false"/' "$MANIFEST" && rm -f "$MANIFEST.bak"; }
for f in android/app/src/main/res/values/styles.xml android/app/src/main/res/values-night/styles.xml; do
  [ -f "$f" ] && sed -i.bak -e 's#@android:style/Theme.Light.NoTitleBar#Theme.AppCompat.Light.NoActionBar#' -e 's#@android:style/Theme.Black.NoTitleBar#Theme.AppCompat.NoActionBar#' "$f" && rm -f "$f.bak"
done

PLIST=ios/Runner/Info.plist
if [[ "$(uname)" == "Darwin" ]] && ! grep -q NSFaceIDUsageDescription "$PLIST"; then
  /usr/libexec/PlistBuddy -c "Add :NSFaceIDUsageDescription string 'Unlock the app with Face ID'" "$PLIST"
fi
echo "Done. Commit android/ and ios/ so CI can build them."
