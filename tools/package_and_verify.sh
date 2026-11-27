#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:?Usage: package_and_verify.sh <path-to-JiaGuIME.app> <out-ipa-path> <expected-version> <expected-build>}"
OUT_IPA="${2:?Missing output IPA path}"
EXPECTED_VER="${3:?Missing expected short version}"
EXPECTED_BUILD="${4:?Missing expected build number}"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: App bundle not found at $APP_PATH"
  exit 1
fi

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

PAYLOAD_DIR="$STAGE_DIR/Payload"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/JiaGuIME.app"

HOST_APP="$PAYLOAD_DIR/JiaGuIME.app"
EXT_APPEX="$HOST_APP/PlugIns/JiaGuKeyboard.appex"

echo "=== QA Step 1: Verify directory & Info.plist presence ==="
test -f "$HOST_APP/Info.plist"
test -d "$EXT_APPEX"
test -f "$EXT_APPEX/Info.plist"

echo "=== QA Step 2: plutil -lint & unresolved variable check ==="
plutil -lint "$HOST_APP/Info.plist"
plutil -lint "$EXT_APPEX/Info.plist"

HOST_XML="$(plutil -convert xml1 -o - "$HOST_APP/Info.plist")"
EXT_XML="$(plutil -convert xml1 -o - "$EXT_APPEX/Info.plist")"
if echo "$HOST_XML" | grep -qE '\$\([A-Za-z0-9_]+\)'; then
  echo "ERROR: Unresolved build variable in Host Info.plist!"
  echo "$HOST_XML"
  exit 1
fi
if echo "$EXT_XML" | grep -qE '\$\([A-Za-z0-9_]+\)'; then
  echo "ERROR: Unresolved build variable in Extension Info.plist!"
  echo "$EXT_XML"
  exit 1
fi

echo "=== QA Step 3: Verify Bundle IDs, Versions, XPC!, MinimumOSVersion, NSExtension ==="
read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

HOST_BID="$(read_plist "$HOST_APP/Info.plist" "CFBundleIdentifier")"
EXT_BID="$(read_plist "$EXT_APPEX/Info.plist" "CFBundleIdentifier")"
HOST_VER="$(read_plist "$HOST_APP/Info.plist" "CFBundleShortVersionString")"
EXT_VER="$(read_plist "$EXT_APPEX/Info.plist" "CFBundleShortVersionString")"
HOST_BUILD="$(read_plist "$HOST_APP/Info.plist" "CFBundleVersion")"
EXT_BUILD="$(read_plist "$EXT_APPEX/Info.plist" "CFBundleVersion")"
EXT_PKG="$(read_plist "$EXT_APPEX/Info.plist" "CFBundlePackageType")"
EXT_MIN_OS="$(read_plist "$EXT_APPEX/Info.plist" "MinimumOSVersion")"
EXT_POINT="$(read_plist "$EXT_APPEX/Info.plist" "NSExtension:NSExtensionPointIdentifier")"
EXT_CLASS="$(read_plist "$EXT_APPEX/Info.plist" "NSExtension:NSExtensionPrincipalClass")"
EXT_OPEN="$(read_plist "$EXT_APPEX/Info.plist" "NSExtension:NSExtensionAttributes:RequestsOpenAccess")"
EXT_LANG="$(read_plist "$EXT_APPEX/Info.plist" "NSExtension:NSExtensionAttributes:PrimaryLanguage")"

echo "Host BID=$HOST_BID Ver=$HOST_VER ($HOST_BUILD)"
echo "Ext  BID=$EXT_BID Ver=$EXT_VER ($EXT_BUILD) Pkg=$EXT_PKG MinOS=$EXT_MIN_OS"
echo "Ext  Point=$EXT_POINT Class=$EXT_CLASS OpenAccess=$EXT_OPEN Lang=$EXT_LANG"

test "$HOST_BID" = "com.custom.ime"
test "$EXT_BID" = "com.custom.ime.keyboard"
test "$HOST_VER" = "$EXPECTED_VER"
test "$EXT_VER" = "$EXPECTED_VER"
test "$HOST_BUILD" = "$EXPECTED_BUILD"
test "$EXT_BUILD" = "$EXPECTED_BUILD"
test "$EXT_PKG" = "XPC!"
test "$EXT_MIN_OS" = "16.0"
test "$EXT_POINT" = "com.apple.keyboard-service"
test "$EXT_CLASS" = "JiaGuKeyboardViewController"
test "$EXT_OPEN" = "true"
test "$EXT_LANG" = "zh-Hans"

echo "=== QA Step 4: Verify arm64 binaries, Assets.car & JGLEX01 lexicon ==="
HOST_EXEC="$(read_plist "$HOST_APP/Info.plist" "CFBundleExecutable")"
EXT_EXEC="$(read_plist "$EXT_APPEX/Info.plist" "CFBundleExecutable")"
test -f "$HOST_APP/$HOST_EXEC"
test -f "$EXT_APPEX/$EXT_EXEC"
lipo -info "$HOST_APP/$HOST_EXEC" | grep -q "arm64"
lipo -info "$EXT_APPEX/$EXT_EXEC" | grep -q "arm64"

test -f "$HOST_APP/Assets.car"
test -f "$EXT_APPEX/jiagu_lexicon.bin"
LEX_MAGIC="$(head -c 7 "$EXT_APPEX/jiagu_lexicon.bin")"
test "$LEX_MAGIC" = "JGLEX01"

echo "=== QA Step 5: Package unsigned IPA and verify zip integrity ==="
mkdir -p "$(dirname "$OUT_IPA")"
ABS_OUT_IPA="$(cd "$(dirname "$OUT_IPA")" && pwd)/$(basename "$OUT_IPA")"
(cd "$STAGE_DIR" && zip -qry "$ABS_OUT_IPA" Payload)
unzip -t "$ABS_OUT_IPA" > /dev/null

ls -lh "$ABS_OUT_IPA"
echo "QA PASSED: $ABS_OUT_IPA"
