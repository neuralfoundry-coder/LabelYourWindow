#!/bin/bash
# Build, notarize, and package for direct distribution (GitHub/website)
# Prerequisites:
#   - Developer ID Application certificate installed in Keychain
#   - App-specific password for notarization:
#     1. Go to appleid.apple.com → App-Specific Passwords → Generate
#     2. Store it: xcrun notarytool store-credentials "LYW-Notary" \
#                    --apple-id "brildev7@gmail.com" \
#                    --team-id YBR9AQ6NVQ \
#                    --password <your-app-specific-password>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="1.2.0"
ARCHIVE_PATH="$PROJECT_ROOT/dist/LabelYourWindow-Direct.xcarchive"
EXPORT_PATH="$PROJECT_ROOT/dist/Direct"
APP_PATH="$EXPORT_PATH/LabelYourWindow.app"
DMG_PATH="$PROJECT_ROOT/dist/LabelYourWindow-v${VERSION}-arm64.dmg"
ZIP_PATH="$PROJECT_ROOT/dist/LabelYourWindow-v${VERSION}-arm64.zip"

cd "$PROJECT_ROOT"

echo "=== Building Release Archive ==="
xcodebuild archive \
  -project LabelYourWindow.xcodeproj \
  -scheme LabelYourWindow \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM=YBR9AQ6NVQ \
  ENABLE_HARDENED_RUNTIME=YES

echo "=== Exporting ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$SCRIPT_DIR/export-options-direct.plist"

echo "=== Notarizing ==="
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "LYW-Notary" \
  --wait

echo "=== Stapling ==="
xcrun stapler staple "$APP_PATH"

echo "=== Creating DMG ==="
if command -v create-dmg &>/dev/null; then
  create-dmg \
    --volname "LabelYourWindow" \
    --volicon "LabelYourWindow/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "LabelYourWindow.app" 140 190 \
    --hide-extension "LabelYourWindow.app" \
    --app-drop-link 400 190 \
    "$DMG_PATH" \
    "$EXPORT_PATH/"
else
  # Fallback: plain zip
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
  echo "create-dmg not found. Install with: brew install create-dmg"
fi

echo ""
echo "Done. Artifacts:"
echo "  DMG: $DMG_PATH"
echo "  ZIP: $ZIP_PATH"
