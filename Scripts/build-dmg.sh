#!/bin/bash
set -euo pipefail

# ============================================================
# Maestro App Factory - Build & Distribution Script
#
# Usage:
#   ./Scripts/build-dmg.sh                    # Build only (no notarize)
#   ./Scripts/build-dmg.sh --notarize         # Build + notarize
#
# Prerequisites:
#   - Xcode with valid signing identity
#   - gh CLI authenticated (for downloading release)
#   - For notarization: notarytool credentials stored as "AC_PASSWORD"
#     (see setup instructions below)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$PROJECT_ROOT/Maestro App Factory"
BUILD_DIR="$PROJECT_ROOT/build"
REPO="SnapdragonPartners/maestro"

# Get latest release version if not specified
if [[ -z "${MAESTRO_VERSION:-}" ]]; then
    MAESTRO_VERSION=$(gh release view --repo "$REPO" --json tagName -q .tagName)
    echo "    (auto-detected latest release)"
fi
NOTARIZE=false

if [[ "${1:-}" == "--notarize" ]]; then
    NOTARIZE=true
fi

echo "==> Maestro App Factory Build Script"
echo "    Maestro CLI version: $MAESTRO_VERSION"
echo ""

# ---- Step 1: Download Maestro binary ----
echo "==> Downloading maestro v${MAESTRO_VERSION} (darwin_arm64)..."
BINARY_DIR="$BUILD_DIR/binary"
mkdir -p "$BINARY_DIR"

ASSET_NAME="maestro_${MAESTRO_VERSION}_darwin_arm64.zip"
DOWNLOAD_PATH="$BINARY_DIR/$ASSET_NAME"

if [[ ! -f "$DOWNLOAD_PATH" ]]; then
    gh release download "v${MAESTRO_VERSION}" \
        --repo "$REPO" \
        --pattern "$ASSET_NAME" \
        --dir "$BINARY_DIR"
fi

# Extract binary
echo "==> Extracting binary..."
unzip -o "$DOWNLOAD_PATH" -d "$BINARY_DIR/extracted" > /dev/null
MAESTRO_BINARY="$BINARY_DIR/extracted/maestro"
chmod +x "$MAESTRO_BINARY"

# Verify it runs
echo "==> Verifying binary..."
"$MAESTRO_BINARY" -version
echo ""

# ---- Step 2: Copy binary into app source ----
echo "==> Copying binary into app bundle resources..."
cp "$MAESTRO_BINARY" "$PROJECT_DIR/Maestro App Factory/maestro"
chmod +x "$PROJECT_DIR/Maestro App Factory/maestro"

# ---- Step 3: Build the Xcode project ----
echo "==> Building Xcode project (Release)..."
ARCHIVE_PATH="$BUILD_DIR/MaestroAppFactory.xcarchive"

xcodebuild -project "$PROJECT_DIR/Maestro App Factory.xcodeproj" \
    -scheme "Maestro App Factory" \
    -configuration Release \
    -destination "platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    | tail -5

echo "==> Archive created at $ARCHIVE_PATH"

# ---- Step 4: Export the archive ----
echo "==> Exporting archive..."
EXPORT_DIR="$BUILD_DIR/export"
rm -rf "$EXPORT_DIR"

# Create ExportOptions.plist
cat > "$BUILD_DIR/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
    | tail -5

APP_PATH="$EXPORT_DIR/Maestro App Factory.app"
echo "==> Exported app at: $APP_PATH"

# ---- Step 5: Sign the embedded Go binary ----
echo "==> Signing embedded Go binary..."
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')

if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "WARNING: No 'Developer ID Application' certificate found."
    echo "         Using automatic signing from archive export."
    echo "         For distribution, you need a Developer ID certificate."
else
    echo "    Signing with: $SIGNING_IDENTITY"
    codesign --force --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp \
        "$APP_PATH/Contents/Resources/maestro"

    # Re-sign the whole app to update the seal
    codesign --force --sign "$SIGNING_IDENTITY" \
        --options runtime --timestamp \
        "$APP_PATH"
fi

# Verify signature
echo "==> Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
echo "    Signature valid."

# ---- Step 6: Create DMG ----
echo "==> Creating DMG..."
DMG_PATH="$BUILD_DIR/MaestroAppFactory-${MAESTRO_VERSION}.dmg"
rm -f "$DMG_PATH"

# Create a temporary DMG folder with app and Applications symlink
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "Maestro App Factory" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

# Sign the DMG
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    echo "==> Signing DMG..."
    codesign --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
fi

echo "==> DMG created at: $DMG_PATH"

# ---- Step 7: Notarize (optional) ----
if [[ "$NOTARIZE" == true ]]; then
    echo "==> Submitting for notarization..."
    echo "    (This may take a few minutes)"

    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "AC_PASSWORD" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"

    echo "==> Notarization complete!"
else
    echo ""
    echo "==> Skipping notarization (run with --notarize to enable)"
    echo "    First-time setup for notarization:"
    echo "    1. Create an app-specific password at https://appleid.apple.com"
    echo "    2. Store credentials:"
    echo "       xcrun notarytool store-credentials \"AC_PASSWORD\" \\"
    echo "         --apple-id \"your@email.com\" \\"
    echo "         --team-id \"VNJH3VB68C\""
fi

echo ""
echo "============================================"
echo "  Build complete!"
echo "  DMG: $DMG_PATH"
echo "============================================"
