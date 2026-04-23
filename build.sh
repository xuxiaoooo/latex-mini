#!/bin/zsh
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_NAME="LatexMini"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon-1024.png"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
VOL_NAME="$APP_NAME"

rm -rf "$APP_DIR" "$DMG_ROOT" "$DMG_PATH" "$MODULE_CACHE_DIR"
mkdir -p "$BIN_DIR" "$RES_DIR" "$MODULE_CACHE_DIR"

NODE_PATH=$(command -v node || true)
PYTHON_FOR_ICON=""

for candidate in \
  /opt/homebrew/Caskroom/miniconda/base/bin/python3 \
  /opt/homebrew/bin/python3 \
  /usr/bin/python3 \
  "$(command -v python3 2>/dev/null || true)"; do
  [[ -n "$candidate" ]] || continue
  [[ -x "$candidate" ]] || continue
  if "$candidate" -c "import PIL" >/dev/null 2>&1; then
    PYTHON_FOR_ICON="$candidate"
    break
  fi
done

if [[ -n "$NODE_PATH" ]]; then
  printf '%s\n' "$NODE_PATH" > "$ROOT_DIR/Resources/Renderer/node-path.txt"
fi

swiftc \
  -Osize \
  -parse-as-library \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -Xcc "-fmodules-cache-path=$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework SwiftUI \
  -framework UniformTypeIdentifiers \
  -framework WebKit \
  "$ROOT_DIR/Sources/LatexMiniApp.swift" \
  -o "$BIN_DIR/$APP_NAME"

cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -R "$ROOT_DIR/Resources/." "$RES_DIR/"
strip -x "$BIN_DIR/$APP_NAME" 2>/dev/null || true

if [[ -f "$ICON_SOURCE" ]]; then
  if [[ -z "$PYTHON_FOR_ICON" ]]; then
    echo "Icon build failed: no python3 with Pillow found" >&2
    exit 1
  fi

  "$PYTHON_FOR_ICON" - "$ICON_SOURCE" "$RES_DIR/AppIcon.icns" <<'PY'
from PIL import Image
import sys

source_path, target_path = sys.argv[1], sys.argv[2]
image = Image.open(source_path).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
image.save(target_path)
PY
fi

mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname "$VOL_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Built app: $APP_DIR"
echo "Built dmg: $DMG_PATH"
