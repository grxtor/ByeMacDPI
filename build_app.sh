#!/bin/bash
APP_NAME="BayMacDPI"
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
swiftc "$SRC_DIR"/*.swift -o "$MACOS_DIR/BayMacDPI" -target arm64-apple-macosx13.0 -swift-version 5

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
    <string>BayMacDPI</string>
    <key>CFBundleIdentifier</key>
    <string>com.baymacdpi.app</string>
    <key>CFBundleName</key>
    <string>BayMacDPI</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.9</string>
    <key>CFBundleVersion</key>
    <string>11</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 BayMacDPI. Licensed under MIT.</string>
</dict>
</plist>
EOF

# PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy bundled ByeDPI binary - check multiple locations
BYEDPI_SRC=""
if [ -f "../byedpi/ciadpi" ]; then
    BYEDPI_SRC="../byedpi/ciadpi"
    echo "Found ciadpi in ../byedpi/"
elif [ -f "Resources/ciadpi" ]; then
    BYEDPI_SRC="Resources/ciadpi"
    echo "Found ciadpi in Resources/"
fi

if [ -n "$BYEDPI_SRC" ]; then
    echo "Copying ByeDPI binary..."
    cp "$BYEDPI_SRC" "$RESOURCES_DIR/ciadpi"
    chmod +x "$RESOURCES_DIR/ciadpi"
    # Remove quarantine attribute
    xattr -d com.apple.quarantine "$RESOURCES_DIR/ciadpi" 2>/dev/null || true
else
    echo "ERROR: ciadpi binary not found!"
    exit 1
fi

# Clean up metadata before signing to prevent "resource fork" errors
echo "Cleaning metadata..."
xattr -cr "$APP_BUNDLE"

# Ad-hoc Code Signing to prevent "Damaged" error
echo "Signing app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build Successful: $APP_BUNDLE"
