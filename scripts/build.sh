#!/bin/bash
# Builds MacPressura as a universal (arm64 + x86_64) Release app:
#   downloads XcodeGen and the pinned 7-Zip engine when missing -> generates the
#   Xcode project -> builds -> ad-hoc signs the bundle.
#
# Output: build/MacPressura.app
# To install and launch the result, run ./scripts/install.sh instead.
#
# Usage:
#   ./scripts/build.sh            build
#   ./scripts/build.sh --clean    remove build products, the generated project and the cached engine first
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP_NAME="MacPressura"
SCHEME="MacPressura"
TOOLS_DIR="$ROOT/.tools"
DERIVED="$ROOT/build/DerivedData"

for arg in "$@"; do
  case "$arg" in
    --clean) rm -rf "$ROOT/build" "$ROOT/$APP_NAME.xcodeproj" "$ROOT/Vendor/7zz" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- Xcode check
log "Checking Xcode"
if ! xcode-select -p >/dev/null 2>&1 || [ ! -x "$(xcode-select -p)/usr/bin/xcodebuild" ]; then
  cat >&2 <<'EOF'
Xcode is required (the Command Line Tools alone cannot build a SwiftUI app).
  1. Install Xcode from the App Store.
  2. Open Xcode once and accept the license.
  3. Run:  sudo xcode-select -s /Applications/Xcode.app
  4. Run ./scripts/build.sh again.
EOF
  exit 1
fi
xcodebuild -version 2>/dev/null | head -1 || true

# ---------------------------------------------------------------- XcodeGen
log "Checking XcodeGen"
XCODEGEN=""
if command -v xcodegen >/dev/null 2>&1; then
  XCODEGEN="$(command -v xcodegen)"
elif [ -x "$TOOLS_DIR/xcodegen/bin/xcodegen" ]; then
  XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"
else
  echo "XcodeGen not found; downloading a local copy into .tools (no Homebrew needed)..."
  mkdir -p "$TOOLS_DIR"
  TMP_ZIP="$(mktemp -t xcodegen).zip"
  curl -fsSL --retry 3 -o "$TMP_ZIP" \
    "https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip"
  rm -rf "$TOOLS_DIR/xcodegen"
  unzip -q -o "$TMP_ZIP" -d "$TOOLS_DIR"
  rm -f "$TMP_ZIP"
  xattr -dr com.apple.quarantine "$TOOLS_DIR/xcodegen" 2>/dev/null || true
  XCODEGEN="$TOOLS_DIR/xcodegen/bin/xcodegen"
  [ -x "$XCODEGEN" ] || fail "XcodeGen download failed."
fi
"$XCODEGEN" --version

# ---------------------------------------------------------------- 7zz
log "Preparing 7-Zip engine (7zz)"
chmod +x "$ROOT/scripts/fetch-7zz.sh"
"$ROOT/scripts/fetch-7zz.sh"
[ -x "$ROOT/Vendor/7zz/7zz" ] || fail "Vendor/7zz/7zz is missing."
# Make sure the engine carries a signature even when it came from an older cache.
if ! codesign --verify "$ROOT/Vendor/7zz/7zz" >/dev/null 2>&1; then
  codesign --force --sign - "$ROOT/Vendor/7zz/7zz"
fi

# ---------------------------------------------------------------- Generate
log "Generating Xcode project"
"$XCODEGEN" generate --spec "$ROOT/project.yml" --project "$ROOT" --quiet

# ---------------------------------------------------------------- Build
log "Building $APP_NAME (Release, universal)"
xcodebuild \
  -project "$ROOT/$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -quiet \
  build

BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[ -d "$BUILT_APP" ] || fail "Build product not found at $BUILT_APP"

# Make sure the bundled engine is executable and the whole bundle is ad-hoc signed.
chmod +x "$BUILT_APP/Contents/MacOS/7zz" 2>/dev/null || true
codesign --force --deep --options runtime --sign - "$BUILT_APP"

rm -rf "$ROOT/build/$APP_NAME.app"
ditto "$BUILT_APP" "$ROOT/build/$APP_NAME.app"

log "Built: build/$APP_NAME.app"
echo "Architectures: $(lipo -archs "$ROOT/build/$APP_NAME.app/Contents/MacOS/$APP_NAME") / engine: $(lipo -archs "$ROOT/build/$APP_NAME.app/Contents/MacOS/7zz")"
