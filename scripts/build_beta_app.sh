#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Project Resume Beta"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/Project-Resume-Beta.zip"
APPCAST_PATH="$ROOT_DIR/dist/appcast.xml"
APP_IDENTIFIER="${PROJECT_RESUME_BUNDLE_ID:-com.projectresume.beta}"
APP_VERSION="${PROJECT_RESUME_VERSION:-0.1.0}"
APP_BUILD="${PROJECT_RESUME_BUILD:-1}"
TEMP_DIR="$ROOT_DIR/dist/.beta-build"
SIGNATURE_INFO_PATH="$TEMP_DIR/sparkle-signature.json"
SPARKLE_KEYS_DIR="$ROOT_DIR/.sparkle"
TEMP_OUTPUT_DIR="$(mktemp -d /tmp/projectresume-beta-bundle.XXXXXX)"
TEMP_APP_BUNDLE="$TEMP_OUTPUT_DIR/$APP_NAME.app"
ICONSET_SOURCE="$ROOT_DIR/Sources/ProjectResume/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

export HOME="${HOME:-/tmp/projectresume-home}"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swiftpm-module-cache"

mkdir -p "$ROOT_DIR/dist"
rm -rf "$TEMP_DIR" "$APP_BUNDLE" "$ZIP_PATH" "$APPCAST_PATH"
mkdir -p "$TEMP_DIR"
trap 'rm -rf "$TEMP_OUTPUT_DIR"' EXIT

swift build --configuration release --package-path "$ROOT_DIR"

BIN_PATH="$(swift build --configuration release --package-path "$ROOT_DIR" --show-bin-path)"
EXECUTABLE_PATH="$BIN_PATH/ProjectResume"
RESOURCE_BUNDLE_PATH="$(find "$BIN_PATH" -maxdepth 1 -type d -name '*.bundle' | head -n 1)"
SPARKLE_FRAMEWORK_PATH="$(find "$ROOT_DIR/.build" -type d -name 'Sparkle.framework' | head -n 1)"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
  echo "Release executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

if [[ -z "$RESOURCE_BUNDLE_PATH" || ! -d "$RESOURCE_BUNDLE_PATH" ]]; then
  echo "SwiftPM resource bundle not found in $BIN_PATH" >&2
  exit 1
fi

if [[ -z "$SPARKLE_FRAMEWORK_PATH" || ! -d "$SPARKLE_FRAMEWORK_PATH" ]]; then
  echo "Sparkle.framework was not found in the build products." >&2
  exit 1
fi

mkdir -p "$TEMP_APP_BUNDLE/Contents/MacOS" "$TEMP_APP_BUNDLE/Contents/Resources" "$TEMP_APP_BUNDLE/Contents/Frameworks"
cp "$EXECUTABLE_PATH" "$TEMP_APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$RESOURCE_BUNDLE_PATH" "$TEMP_APP_BUNDLE/Contents/Resources/"
cp -R "$SPARKLE_FRAMEWORK_PATH" "$TEMP_APP_BUNDLE/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$TEMP_APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true

ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

for icon in "$ICONSET_SOURCE"/*.png; do
  cp "$icon" "$ICONSET_DIR/$(basename "$icon")"
done

iconutil -c icns "$ICONSET_DIR" -o "$TEMP_APP_BUNDLE/Contents/Resources/AppIcon.icns"
SPARKLE_PUBLIC_KEY="$(swift "$ROOT_DIR/scripts/sparkle_sign.swift" public-key "$SPARKLE_KEYS_DIR")"

cat > "$TEMP_APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${APP_IDENTIFIER}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Project Resume Beta</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
  <key>SUEnableInstallerLauncherService</key>
  <true/>
  <key>SUFeedURL</key>
  <string>http://127.0.0.1:8757/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>${SPARKLE_PUBLIC_KEY}</string>
</dict>
</plist>
EOF

xattr -cr "$TEMP_APP_BUNDLE"
codesign --force --deep --sign - "$TEMP_APP_BUNDLE"
ditto -c -k --sequesterRsrc --keepParent "$TEMP_APP_BUNDLE" "$ZIP_PATH"
swift "$ROOT_DIR/scripts/sparkle_sign.swift" sign "$ZIP_PATH" "$SPARKLE_KEYS_DIR" > "$SIGNATURE_INFO_PATH"
SPARKLE_SIGNATURE="$(plutil -extract signature raw -expect string -o - "$SIGNATURE_INFO_PATH")"
SPARKLE_ZIP_URL="$(plutil -extract fileURL raw -expect string -o - "$SIGNATURE_INFO_PATH")"
SPARKLE_ZIP_SIZE="$(plutil -extract fileSize raw -expect integer -o - "$SIGNATURE_INFO_PATH")"
APPCAST_DATE="$(LC_ALL=en_US.UTF-8 date -u +"%a, %d %b %Y %H:%M:%S +0000")"

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>${APP_NAME}</title>
    <link>http://127.0.0.1:8757/appcast.xml</link>
    <description>Project Resume Beta updates</description>
    <language>en</language>
    <item>
      <title>Version ${APP_VERSION} (${APP_BUILD})</title>
      <pubDate>${APPCAST_DATE}</pubDate>
      <enclosure
        url="Project-Resume-Beta.zip"
        sparkle:version="${APP_BUILD}"
        sparkle:shortVersionString="${APP_VERSION}"
        sparkle:edSignature="${SPARKLE_SIGNATURE}"
        length="${SPARKLE_ZIP_SIZE}"
        type="application/octet-stream" />
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
EOF

ditto "$TEMP_APP_BUNDLE" "$APP_BUNDLE"

echo "Beta app created:"
echo "  $APP_BUNDLE"
echo "Zip archive created:"
echo "  $ZIP_PATH"
echo "Sparkle appcast created:"
echo "  $APPCAST_PATH"
echo "Tip:"
echo "  If the project folder is iCloud-backed, install from the zip for the cleanest beta artifact."
