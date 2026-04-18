#!/bin/bash
# Build and submit to Mac App Store
# Prerequisites:
#   - Apple Distribution certificate installed in Keychain
#   - "LabelYourWindow AppStore" provisioning profile downloaded from developer.apple.com
#   - App registered on App Store Connect (https://appstoreconnect.apple.com)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARCHIVE_PATH="$PROJECT_ROOT/dist/LabelYourWindow-AppStore.xcarchive"
EXPORT_PATH="$PROJECT_ROOT/dist/AppStore"

cd "$PROJECT_ROOT"

echo "=== Building AppStore Archive ==="
xcodebuild archive \
  -project LabelYourWindow.xcodeproj \
  -scheme LabelYourWindow \
  -configuration AppStore \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=YBR9AQ6NVQ \
  | xcpretty 2>/dev/null || true

echo "=== Exporting and Uploading to App Store Connect ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$SCRIPT_DIR/export-options-appstore.plist"

echo ""
echo "Done. App uploaded to App Store Connect."
echo "Next: visit https://appstoreconnect.apple.com → Your App → TestFlight or submit for review."
