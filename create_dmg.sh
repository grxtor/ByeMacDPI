#!/bin/bash
# Create Styled DMG for BayMacDPI
# Requires: Resources/dmg_background.png

APP_NAME="BayMacDPI"
BUILD_DIR="Build"
DMG_NAME="$APP_NAME.dmg"
VOL_NAME="$APP_NAME"
BG_IMG="Resources/dmg_background.png"

# Check if app exists
if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "Error: $BUILD_DIR/$APP_NAME.app not found"
    echo "Run ./build_app.sh first"
    exit 1
fi

# Clean up old files
rm -f "$BUILD_DIR/$DMG_NAME"
rm -f "$BUILD_DIR/pack.temp.dmg"

echo "Creating temporary DMG..."
# Create a temporary read/write DMG
hdiutil create \
    -srcfolder "$BUILD_DIR/$APP_NAME.app" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200M \
    "$BUILD_DIR/pack.temp.dmg"

echo "Mounting DMG..."
# Mount and save the device node
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$BUILD_DIR/pack.temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')

echo "Setting up content..."
# Wait for mount
sleep 2

# Copy background
mkdir -p "/Volumes/$VOL_NAME/.background"
cp "$BG_IMG" "/Volumes/$VOL_NAME/.background/background.png"

# Create Applications symlink
ln -s /Applications "/Volumes/$VOL_NAME/Applications"

echo "Applying style via AppleScript..."
# AppleScript to set window style
osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 500}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position App Icon
        set position of item "$APP_NAME.app" of container window to {160, 200}
        
        -- Position Applications Shortcut
        set position of item "Applications" of container window to {440, 200}
        
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

echo "Finalizing DMG..."
# Sync and detach
sync
hdiutil detach "$DEVICE"

echo "Compressing DMG..."
# Convert to compressed read-only DMG
hdiutil convert "$BUILD_DIR/pack.temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$BUILD_DIR/$DMG_NAME"

# Cleanup
rm -f "$BUILD_DIR/pack.temp.dmg"

echo "DMG Created Successfully: $BUILD_DIR/$DMG_NAME"
ls -lh "$BUILD_DIR/$DMG_NAME"
