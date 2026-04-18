#!/bin/bash
# Upload pre-built AppStore archive to App Store Connect
# Run this AFTER creating the app on App Store Connect:
#   https://appstoreconnect.apple.com → My Apps → + → New Mac App
#   Bundle ID: com.labelyourwindow.app  |  SKU: LABELYOURWINDOW2026
#
# The archive is already built and signed at: dist/LabelYourWindow-AppStore.xcarchive

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ARCHIVE_PATH="$PROJECT_ROOT/dist/LabelYourWindow-AppStore.xcarchive"
EXPORT_PATH="$PROJECT_ROOT/dist/AppStoreExport"
KEY_PATH="$HOME/AuthKey_C6CQS79SR7.p8"

cd "$PROJECT_ROOT"

echo "=== Uploading to App Store Connect ==="
echo "Archive: $ARCHIVE_PATH"

mkdir -p "$EXPORT_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$SCRIPT_DIR/export-options-appstore.plist" \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "C6CQS79SR7" \
  -authenticationKeyIssuerID "69a6de94-d8d0-47e3-e053-5b8c7c11a4d1"

echo ""
echo "Done. Visit App Store Connect to submit for review:"
echo "  https://appstoreconnect.apple.com"
