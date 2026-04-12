#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.."; pwd)"
APP_NAME="BrowserProfileLauncher"
BIN_NAME="BrowserProfileLauncher"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

cd "$ROOT_DIR"
swift build -c release --product "$BIN_NAME" >/dev/null
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$BIN_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Binary not found: $BIN_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$BIN_NAME"
chmod +x "$MACOS_DIR/$BIN_NAME"

cat > "$PLIST_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>BrowserProfileLauncher</string>
  <key>CFBundleDisplayName</key>
  <string>BrowserProfileLauncher</string>
  <key>CFBundleIdentifier</key>
  <string>local.dev.browserprofilelauncher</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>BrowserProfileLauncher</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Packaged: $APP_DIR"
