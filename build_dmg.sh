#!/bin/bash
set -e

echo "📦 Creating DMG for Yandex Music Island..."

APP_NAME="YandexMusicIsland"
DMG_NAME="${APP_NAME}.dmg"
SRC_APP="$HOME/Applications/${APP_NAME}.app"

# Check if the app exists
if [ ! -d "$SRC_APP" ]; then
    echo "❌ Error: $SRC_APP not found. Please run build.sh first."
    exit 1
fi

# Prepare a temporary folder for DMG contents
mkdir -p dmg_root
cp -r "$SRC_APP" dmg_root/
ln -s /Applications dmg_root/Applications

# Remove old DMG if it exists
rm -f "$DMG_NAME"

# Create the DMG using hdiutil
echo "💿 Generating disk image..."
hdiutil create -volname "Yandex Music Island" -srcfolder dmg_root -ov -format UDZO "$DMG_NAME"

# Clean up
rm -rf dmg_root

echo "✅ DMG created successfully: $(pwd)/$DMG_NAME"
