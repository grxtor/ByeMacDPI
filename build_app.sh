#!/bin/bash
APP_NAME="ByeDPI Manager"
SRC_DIR="Sources"
BUILD_DIR="Build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile
echo "Compiling Swift Sources..."
swiftc "$SRC_DIR"/*.swift -o "$MACOS_DIR/ByeDPIManager" -target arm64-apple-macosx15.0 -swift-version 5

if [ $? -ne 0 ]; then
    echo "Compilation FAILED"
    exit 1
fi

# Info.plist
echo "Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ByeDPIManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.byedpimanager</string>
    <key>CFBundleName</key>
    <string>ByeDPI Manager</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "Build Successful: $APP_BUNDLE"
