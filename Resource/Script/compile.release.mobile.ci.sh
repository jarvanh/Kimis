#!/bin/zsh

set -e

echo "[*] building project for release"

cd "$(dirname "$0")"/../../
WORKING_ROOT=$(pwd)
echo "[*] working root: $WORKING_ROOT"

if [ ! -f .root ]; then
    echo "[E] malformed project directory"
    exit 1
fi

TIMESTAMP=$(date +%s)
BUILD_DIR="$WORKING_ROOT/.build/release/$TIMESTAMP/XcodeBuild"

SIGNING_ENT="$WORKING_ROOT/Kimis/Kimis.entitlements"

echo "[*] build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ============================================================================
echo "[*] building project for iOS"
DERIVED_LOCATION_IOS="$BUILD_DIR/IOS"
mkdir -p "$DERIVED_LOCATION_IOS"
PRODUCT_LOCATION_IOS="$DERIVED_LOCATION_IOS/Build/Products/Release-iphoneos"
PRODUCT_LOCATION_APP_IOS="$PRODUCT_LOCATION_IOS/Kimis.app"
XCODEBUILD_LOG_FILE_IOS="$DERIVED_LOCATION_IOS/xcodebuild.log"
echo "[*] build with log at: $XCODEBUILD_LOG_FILE_IOS"

xcodebuild \
    -workspace "$WORKING_ROOT/Kimis.xcworkspace" \
    -scheme Kimis \
    -configuration Release \
    -derivedDataPath "$DERIVED_LOCATION_IOS" \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" CODE_SIGNING_ALLOWED="NO" \
    GCC_GENERATE_DEBUGGING_SYMBOLS=YES STRIP_INSTALLED_PRODUCT=NO \
    COPY_PHASE_STRIP=NO UNSTRIPPED_PRODUCT=NO \
    | tee "$XCODEBUILD_LOG_FILE_MACOS" \
    | xcbeautify --is-ci --quiet


echo "[*] looking for app at $PRODUCT_LOCATION_APP_IOS"

if [ ! -d "$PRODUCT_LOCATION_APP_IOS" ]; then
    echo "[E] product could not be found"
    exit 1
fi

echo "[*] signing locally..."
codesign --force --deep --options runtime --sign - --entitlements "$SIGNING_ENT" "$PRODUCT_LOCATION_APP_IOS"
echo "[*] verifying signature..."
codesign --verify --deep --strict --verbose=2 "$PRODUCT_LOCATION_APP_IOS"

echo "[*] packaging product for iOS..."
cd "$PRODUCT_LOCATION_IOS"
mkdir "Payload"
cp -rf "Kimis.app" "Payload/Kimis.app"
zip -r "Kimis.iOS.$TIMESTAMP.ipa" "Payload"
rm -rf "Payload"
cp "Kimis.iOS.$TIMESTAMP.ipa" "$WORKING_ROOT/Kimis.ipa"

echo "[*] done"