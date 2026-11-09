#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release --product FloatKitchen
APP="$PWD/build/Float Kitchen.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ ! -f build/Kitchen.icns || Sources/FloatKitchen/Assets/chefs.png -nt build/Kitchen.icns || scripts/make-kitchen-icon.swift -nt build/Kitchen.icns ]]; then
  swift scripts/make-kitchen-icon.swift Sources/FloatKitchen/Assets/chefs.png build/Kitchen-icon.png
  mkdir -p build/Kitchen.iconset
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" build/Kitchen-icon.png --out "build/Kitchen.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" build/Kitchen-icon.png --out "build/Kitchen.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns build/Kitchen.iconset -o build/Kitchen.icns
fi
cp .build/release/FloatKitchen "$APP/Contents/MacOS/FloatKitchen"
mkdir -p "$APP/Contents/Resources/Assets"
cp .build/release/FloatKitchen_FloatKitchen.bundle/Assets/kitchen.png "$APP/Contents/Resources/Assets/"
cp .build/release/FloatKitchen_FloatKitchen.bundle/Assets/chef-states.png "$APP/Contents/Resources/Assets/"
rm -f "$APP/Contents/Resources/Assets/activity-props.png" "$APP/Contents/Resources/Assets/chefs.png"
cp docs/动作说明书.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FloatKitchen</string>
<key>CFBundleIdentifier</key><string>studio.float.kitchen</string>
<key>CFBundleName</key><string>Float Kitchen</string>
<key>CFBundleDisplayName</key><string>Float Kitchen</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>Kitchen.icns</string>
</dict></plist>
PLIST
if [[ -f build/Kitchen.icns ]]; then cp build/Kitchen.icns "$APP/Contents/Resources/"; fi
codesign --force --deep --sign - "$APP"
print "Built: $APP"
