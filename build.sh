#!/bin/bash
set -e

echo "🔨 Building YandexMusicIsland..."

cd "$(dirname "$0")"

# Build release
swift build -c release 2>&1

echo "📦 Packaging .app bundle..."

# Create app bundle structure
APP_DIR="YandexMusicIsland.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp .build/release/YandexMusicIsland "$APP_DIR/Contents/MacOS/"

# Copy Info.plist and Icon
cp Info.plist "$APP_DIR/Contents/"
cp AppIcon.icns "$APP_DIR/Contents/Resources/" || true

# Remove quarantine attribute
xattr -cr "$APP_DIR" 2>/dev/null || true

# Install to ~/Applications
mkdir -p ~/Applications
rm -rf ~/Applications/"$APP_DIR"
cp -R "$APP_DIR" ~/Applications/
rm -rf "$APP_DIR"

echo "✅ Built successfully!"
echo "📍 App location: ~/Applications/$APP_DIR"
echo ""
echo "To run: open ~/Applications/$APP_DIR"
