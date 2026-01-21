#!/bin/bash

# Build script for Gunbound Aim Assistant (Swift version) - Creates .app bundle

set -e  # Exit on error

echo "🔨 Building Gunbound Aim Assistant (Swift) with App Bundle..."
echo ""

# Configuration
APP_NAME="GunboundAimAssistant"
BUILD_CONFIG="${1:-debug}"  # debug or release
BUNDLE_ID="com.gunbound.aimassistant"
VERSION="1.0.0"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
swift package clean
rm -rf ".build/${BUILD_CONFIG}/${APP_NAME}.app"

# Build the project
echo "📦 Building project (${BUILD_CONFIG})..."
swift build -c ${BUILD_CONFIG}

# Create app bundle structure
echo "📱 Creating app bundle..."
APP_DIR=".build/${BUILD_CONFIG}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
echo "📋 Copying executable..."
cp ".build/${BUILD_CONFIG}/${APP_NAME}" "${MACOS_DIR}/"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${APP_NAME}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<false/>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
</dict>
</plist>
EOF

# Create app icon from Assets.xcassets
if [ -d "Assets.xcassets/AppIcon.appiconset" ]; then
	echo "🎨 Creating app icon..."
	
	# Use pre-generated .icns if it exists in project root
	if [ -f "AppIcon.icns" ]; then
		cp "AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
		echo "✅ App icon copied from AppIcon.icns"
	else
		# Generate .icns from PNG files using sips and iconutil
		TEMP_ICONSET="${RESOURCES_DIR}/AppIcon.iconset"
		mkdir -p "${TEMP_ICONSET}"
		
		# Generate all required icon sizes from the largest PNG
		LARGEST_ICON="Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
		if [ -f "${LARGEST_ICON}" ]; then
			sips -z 16 16 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_16x16.png" >/dev/null 2>&1
			sips -z 32 32 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_16x16@2x.png" >/dev/null 2>&1
			sips -z 32 32 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_32x32.png" >/dev/null 2>&1
			sips -z 64 64 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_32x32@2x.png" >/dev/null 2>&1
			sips -z 128 128 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_128x128.png" >/dev/null 2>&1
			sips -z 256 256 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_128x128@2x.png" >/dev/null 2>&1
			sips -z 256 256 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_256x256.png" >/dev/null 2>&1
			sips -z 512 512 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_256x256@2x.png" >/dev/null 2>&1
			sips -z 512 512 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_512x512.png" >/dev/null 2>&1
			sips -z 1024 1024 "${LARGEST_ICON}" --out "${TEMP_ICONSET}/icon_512x512@2x.png" >/dev/null 2>&1
			
			# Convert iconset to icns
			if iconutil -c icns "${TEMP_ICONSET}" -o "${RESOURCES_DIR}/AppIcon.icns" 2>/dev/null; then
				echo "✅ App icon created successfully"
				rm -rf "${TEMP_ICONSET}"
			else
				echo "⚠️  iconutil failed, keeping iconset folder"
			fi
		else
			echo "⚠️  Could not find source icon file"
		fi
	fi
fi

# Set executable permissions
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo ""
echo "✅ App bundle created successfully!"
echo ""
echo "📍 Location: ${APP_DIR}"
echo ""
echo "To run the application:"
echo "  open ${APP_DIR}"
echo ""
echo "To install to Applications folder:"
echo "  cp -r ${APP_DIR} /Applications/"
echo ""
