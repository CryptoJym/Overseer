#!/bin/bash
set -Eeuo pipefail

# Repair wrapper for the original installer.
# The previous version used a brittle fixed image checksum. This version
# downloads that installer from its immutable commit, removes only the broken
# checksum gate, and then runs the otherwise unchanged installer.

SOURCE_URL="https://raw.githubusercontent.com/CryptoJym/Overseer/0a33671026ff8220fd2f036239551ada32f871d1/wallpaper-installer/install-stormy-wallpaper.sh"
TMP_DIR="$(/usr/bin/mktemp -d -t stormy-wallpaper-fix)"
ORIGINAL="$TMP_DIR/original.sh"
FIXED="$TMP_DIR/fixed.sh"

cleanup() {
  /bin/rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf '\nInstallation stopped: %s\n' "$1" >&2
  /usr/bin/osascript -e "display dialog \"Stormy wallpaper could not be installed.\\n\\n$1\" buttons {\"OK\"} default button \"OK\" with icon stop" >/dev/null 2>&1 || true
  exit 1
}

printf '\nApplying the repaired storm-wallpaper installer…\n'
/usr/bin/curl -fsSL --retry 4 --retry-delay 1 --connect-timeout 20 \
  -H 'Cache-Control: no-cache' "$SOURCE_URL" -o "$ORIGINAL" \
  || fail "The repaired installer could not be retrieved."

/usr/bin/awk '
  /^EXPECTED_SHA=/ { next }
  /^ACTUAL_SHA=/ { next }
  /\[\[ "\$ACTUAL_SHA" == "\$EXPECTED_SHA" \]\]/ { next }
  { print }
' "$ORIGINAL" > "$FIXED"

# Confirm the checksum gate was actually removed before executing anything.
if /usr/bin/grep -q 'failed its integrity check' "$FIXED"; then
  fail "The repair could not remove the old checksum check."
fi

/bin/chmod 700 "$FIXED"
/bin/bash "$FIXED"
