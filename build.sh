#!/bin/bash
set -e

# Configuration
APP_NAME="FocusDesk"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SDK_PATH=$(xcrun --show-sdk-path)

echo "=== Building ${APP_NAME} ==="
echo "SDK Path: ${SDK_PATH}"

# 1. Clean and recreate directory structure
echo "Recreating app bundle structure..."
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 2. Compile Swift sources
echo "Compiling Swift files..."
swiftc \
  -sdk "${SDK_PATH}" \
  -O \
  -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
  src/KeyboardShortcutManager.swift \
  src/FocusEngine.swift \
  src/OnboardingView.swift \
  src/PreferencesView.swift \
  src/main.swift

# 3. Copy Info.plist and resources
echo "Copying Info.plist..."
cp src/Info.plist "${APP_BUNDLE}/Contents/Info.plist"
echo "Copying AppIcon.icns..."
cp src/AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# 4. Sign the app bundle
echo "Ad-hoc codesigning executable..."
codesign --force --sign - --entitlements src/FocusDesk.entitlements "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Ad-hoc codesigning app bundle..."
codesign --force --sign - "${APP_BUNDLE}"

echo "=== Build Successful! ==="
echo "Application bundle created at: $(pwd)/${APP_BUNDLE}"
echo "You can run the app with: open ${APP_BUNDLE}"
