#!/bin/bash
set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="HotKeyTrack"
BUILD_DIR="$PROJ_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=== 编译 release ==="
cd "$PROJ_DIR"
swift build -c release 2>&1

echo "=== 组装 .app ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BUILD_DIR/release/$APP_NAME" "$MACOS/$APP_NAME"
cp "$PROJ_DIR/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJ_DIR/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"

echo "=== 签名（稳定自签名证书）==="
SIGN_ID="HotKeyTrack Self-Signed"
if security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
    codesign --force --deep --sign "$SIGN_ID" "$APP_BUNDLE" 2>&1
else
    echo "未找到证书「$SIGN_ID」，回退 ad-hoc（授权会失效，请先运行 setup_signing.sh）"
    codesign --force --deep --sign - "$APP_BUNDLE" 2>&1
fi

echo "=== 完成 ==="
echo "$APP_BUNDLE"
