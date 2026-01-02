#!/bin/bash
# Create DMG for BayMacDPI

APP_NAME="BayMacDPI"
BUILD_DIR="Build"
DMG_NAME="$APP_NAME.dmg"

# Check if app exists
if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "Error: $BUILD_DIR/$APP_NAME.app not found"
    echo "Run ./build_app.sh first"
    exit 1
fi

# Remove old DMG
rm -f "$BUILD_DIR/$DMG_NAME"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$BUILD_DIR/$APP_NAME.app" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

if [ $? -eq 0 ]; then
    echo "DMG created: $BUILD_DIR/$DMG_NAME"
    ls -lh "$BUILD_DIR/$DMG_NAME"
else
    echo "DMG creation failed"
    exit 1
fi
