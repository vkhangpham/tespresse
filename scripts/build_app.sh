#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="T'es pressé ?.app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME"

echo "Building release executable..."
swift build -c release --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$ROOT_DIR/App/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN_DIR/TesPresse" "$APP_DIR/Contents/MacOS/TesPresse"
chmod +x "$APP_DIR/Contents/MacOS/TesPresse"

while IFS= read -r -d '' bundle_path; do
  cp -R "$bundle_path" "$APP_DIR/Contents/Resources/"
done < <(find "$BIN_DIR" -maxdepth 1 -type d -name 'TesPresse*.bundle' -print0)

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "Bundle created at:"
echo "$APP_DIR"
