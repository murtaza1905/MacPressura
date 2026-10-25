#!/bin/bash
# Downloads the official 7-Zip macOS binary (7zz, universal) into Vendor/7zz,
# verifies its SHA-256 and caches it for later builds.
set -euo pipefail

SEVENZIP_VERSION="26.05"
SEVENZIP_TAG="2605"
SEVENZIP_SHA256="12ef6830317743cfd3f0ab1724bde43fcc270d8b6d8564f8c12c2a2b7f993570"
SEVENZIP_URL="https://github.com/ip7z/7zip/releases/download/${SEVENZIP_VERSION}/7z${SEVENZIP_TAG}-mac.tar.xz"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$ROOT/Vendor/7zz"
STAMP="$DEST_DIR/.version"

if [ -x "$DEST_DIR/7zz" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$SEVENZIP_VERSION" ]; then
  echo "7zz ${SEVENZIP_VERSION} already present."
  exit 0
fi

echo "Downloading 7-Zip ${SEVENZIP_VERSION} (7zz, macOS universal)..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "$TMP/7zz.tar.xz" "$SEVENZIP_URL"

ACTUAL_SHA="$(shasum -a 256 "$TMP/7zz.tar.xz" | awk '{print $1}')"
if [ "$ACTUAL_SHA" != "$SEVENZIP_SHA256" ]; then
  echo "ERROR: SHA-256 mismatch for 7zz download." >&2
  echo "  expected: $SEVENZIP_SHA256" >&2
  echo "  actual:   $ACTUAL_SHA" >&2
  exit 1
fi

mkdir -p "$TMP/x"
tar -xJf "$TMP/7zz.tar.xz" -C "$TMP/x"

if [ ! -f "$TMP/x/7zz" ]; then
  echo "ERROR: 7zz binary not found inside the downloaded archive." >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$TMP/x/7zz" "$DEST_DIR/7zz"
chmod 755 "$DEST_DIR/7zz"
[ -f "$TMP/x/License.txt" ] && cp "$TMP/x/License.txt" "$DEST_DIR/License.txt"
[ -f "$TMP/x/History.txt" ] && cp "$TMP/x/History.txt" "$DEST_DIR/History.txt"
xattr -d com.apple.quarantine "$DEST_DIR/7zz" 2>/dev/null || true
echo "$SEVENZIP_VERSION" > "$STAMP"

echo "7zz ${SEVENZIP_VERSION} ready at Vendor/7zz/7zz"
