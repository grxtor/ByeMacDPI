#!/bin/bash
APP_NAME="ByeMacDPI"
SRC_DIR="Sources"
BUILD_DIR="Build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile for Apple Silicon (ARM64) Only
echo "Compiling Swift Sources (ARM64)..."
swiftc "$SRC_DIR"/*.swift -o "$MACOS_DIR/ByeMacDPI" -target arm64-apple-macosx13.0 -swift-version 5

if [ $? -ne 0 ]; then
    echo "Compilation FAILED"
    exit 1
fi



# Copy AppIcon.icns
if [ -f "$SRC_DIR/AppIcon.icns" ]; then
    echo "Copying AppIcon.icns..."
    cp "$SRC_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Info.plist
echo "Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ByeMacDPI</string>
    <key>CFBundleIdentifier</key>
    <string>com.byemacdpi.app</string>
    <key>CFBundleName</key>
    <string>ByeMacDPI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>20</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ByeMacDPI. Licensed under GPL v3.</string>
</dict>
</plist>
EOF

# PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# ciadpi is now downloaded at runtime by DependencyManager
echo "Skipping ciadpi bundling (downloaded at runtime)"

# Clean up metadata before signing to prevent "resource fork" errors
echo "Cleaning metadata..."
xattr -cr "$APP_BUNDLE"

# Ad-hoc Code Signing to prevent "Damaged" error
echo "Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build Successful: $APP_BUNDLE"
