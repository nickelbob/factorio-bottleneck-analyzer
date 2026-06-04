#!/bin/bash
# Build a release zip for bottleneck-analyzer.
# Cross-platform: uses `zip` (macOS/Linux/git-bash) and falls back to 7-Zip on Windows.
# Usage: ./build_release.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get version from info.json
VERSION=$(grep '"version"' info.json | sed 's/.*"version": "\([^"]*\)".*/\1/')
MOD_NAME="bottleneck-analyzer"
ZIP_NAME="${MOD_NAME}_${VERSION}"

# Build in parent directory
cd ..

# Clean up any existing build
rm -rf "$ZIP_NAME" "$ZIP_NAME.zip"

# Stage files, excluding dev/build artifacts. Prefer rsync; fall back to cp + rm.
if command -v rsync >/dev/null 2>&1; then
  mkdir -p "$ZIP_NAME"
  rsync -a \
    --exclude '.git' --exclude '.gitignore' --exclude '.claude' \
    --exclude 'CLAUDE.md' --exclude 'build_release.sh' \
    --exclude '.DS_Store' --exclude '*.zip' \
    "$MOD_NAME"/ "$ZIP_NAME"/
else
  mkdir -p "$ZIP_NAME"
  cp -r "$MOD_NAME"/* "$ZIP_NAME/"
  rm -rf "$ZIP_NAME/.git" "$ZIP_NAME/.claude"
  rm -f "$ZIP_NAME/CLAUDE.md" "$ZIP_NAME/build_release.sh" "$ZIP_NAME/.DS_Store"
  find "$ZIP_NAME" -name '.DS_Store' -delete 2>/dev/null || true
fi

# Create the zip. Use `zip` if present (macOS/Linux/git-bash); otherwise 7-Zip on Windows.
if command -v zip >/dev/null 2>&1; then
  # -X strips extra file attributes for a cleaner, reproducible archive.
  zip -r -X "$ZIP_NAME.zip" "$ZIP_NAME" >/dev/null
elif [ -x "/c/Program Files/7-Zip/7z.exe" ]; then
  "/c/Program Files/7-Zip/7z.exe" a -tzip "$ZIP_NAME.zip" "$ZIP_NAME" >/dev/null
elif command -v 7z >/dev/null 2>&1; then
  7z a -tzip "$ZIP_NAME.zip" "$ZIP_NAME" >/dev/null
else
  echo "Error: no zip tool found (need 'zip' or 7-Zip)." >&2
  rm -rf "$ZIP_NAME"
  exit 1
fi

# Clean up build directory
rm -rf "$ZIP_NAME"

echo "Created $ZIP_NAME.zip"
