#!/bin/bash
# Create Simple DMG for ByeMacDPI

APP_NAME="ByeMacDPI"
BUILD_DIR="Build"
DMG_NAME="$APP_NAME.dmg"
VOL_NAME="$APP_NAME"

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
hdiutil create \
    -srcfolder "$BUILD_DIR/$APP_NAME.app" \
    -volname "$VOL_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200M \
    "$BUILD_DIR/pack.temp.dmg"

echo "Mounting DMG..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$BUILD_DIR/pack.temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}')

echo "Setting up content..."
sleep 2

# Create Applications symlink
ln -s /Applications "/Volumes/$VOL_NAME/Applications"

echo "Applying style via AppleScript..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 150, 850, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        
        set position of item "$APP_NAME.app" of container window to {110, 120}
        set position of item "Applications" of container window to {340, 120}
        
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

echo "Finalizing DMG..."
sync
hdiutil detach "$DEVICE"

echo "Compressing DMG..."
hdiutil convert "$BUILD_DIR/pack.temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$BUILD_DIR/$DMG_NAME"

rm -f "$BUILD_DIR/pack.temp.dmg"

echo "DMG Created Successfully: $BUILD_DIR/$DMG_NAME"
ls -lh "$BUILD_DIR/$DMG_NAME"
