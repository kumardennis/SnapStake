#!/bin/sh
# Flutter iOS codesign fails under iCloud Documents because macOS stamps
# com.apple.provenance / FinderInfo on build products ("resource fork... detritus
# not allowed"). Keep the project's build/ directory as a symlink into /tmp.
set -e
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="/tmp/snapstake_flutter_build"
mkdir -p "$TARGET"
# Clear any xattrs that may have been copied in from Documents.
/usr/bin/xattr -cr "$TARGET" 2>/dev/null || true

if [ -L build ]; then
  current="$(readlink build)"
  if [ "$current" = "$TARGET" ]; then
    exit 0
  fi
  rm -f build
elif [ -e build ]; then
  # Move existing artifacts out of iCloud Documents without copying xattrs.
  rsync -a --no-xattrs build/ "$TARGET/" 2>/dev/null || rsync -a build/ "$TARGET/" 2>/dev/null || true
  /usr/bin/xattr -cr "$TARGET" 2>/dev/null || true
  chmod -R u+w build 2>/dev/null || true
  rm -rf build
fi

ln -sfn "$TARGET" build
echo "build -> $TARGET (codesign-safe)"
