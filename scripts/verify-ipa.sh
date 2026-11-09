#!/usr/bin/env bash
# verify-ipa.sh — hard checks on the unsigned Sdab.ipa before it is handed to a re-signer.
#
# Usage: bash scripts/verify-ipa.sh [Sdab.ipa]
#
# Exits non-zero if the IPA is not a valid arm64 iOS app bundle. This is meant to
# run on macOS (GitHub Actions) because it uses lipo/otool/vtool/plutil.

set -euo pipefail

IPA="${1:-Sdab.ipa}"
EXPECTED_BUNDLE_ID="com.sdab.app"
EXPECTED_MIN_OS="16.0"

fail() {
  echo "::error::$*"
  exit 1
}

info() {
  echo "• $*"
}

[ -f "$IPA" ] || fail "IPA not found: $IPA"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Unzip without modifying the archive. macOS unzip preserves POSIX permissions.
unzip -q "$IPA" -d "$WORK"

echo "::group::Payload tree"
find "$WORK/Payload" -print | sed "s|$WORK/||" | sort
echo "::endgroup::"

PAYLOAD="$WORK/Payload"
APP="$PAYLOAD/Sdab.app"

[ -d "$APP" ] || fail "Payload/Sdab.app is missing"
[ "$(find "$PAYLOAD" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = "1" ] \
  || fail "Payload must contain exactly one item (Sdab.app)"

# ---------------------------------------------------------------------------
# Info.plist
# ---------------------------------------------------------------------------
PLIST="$APP/Info.plist"
[ -f "$PLIST" ] || fail "Info.plist missing"

echo "::group::Info.plist"
plutil -lint "$PLIST"
plutil -p "$PLIST"
echo "::endgroup::"

plist_get() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null
}

EXE_NAME="$(plist_get CFBundleExecutable || true)"
[ -n "$EXE_NAME" ] || fail "CFBundleExecutable missing from Info.plist"

BUNDLE_ID="$(plist_get CFBundleIdentifier || true)"
[ "$BUNDLE_ID" = "$EXPECTED_BUNDLE_ID" ] \
  || fail "CFBundleIdentifier is '$BUNDLE_ID', expected '$EXPECTED_BUNDLE_ID'"

MIN_OS="$(plist_get MinimumOSVersion || true)"
[ "$MIN_OS" = "$EXPECTED_MIN_OS" ] \
  || fail "MinimumOSVersion is '$MIN_OS', expected '$EXPECTED_MIN_OS'"

PKG_TYPE="$(plist_get CFBundlePackageType || true)"
[ "$PKG_TYPE" = "APPL" ] || fail "CFBundlePackageType is '$PKG_TYPE', expected APPL"

SHORT_VERSION="$(plist_get CFBundleShortVersionString || true)"
BUILD_VERSION="$(plist_get CFBundleVersion || true)"
[ -n "$SHORT_VERSION" ] || fail "CFBundleShortVersionString missing"
[ -n "$BUILD_VERSION" ] || fail "CFBundleVersion missing"

PLATFORMS="$(plist_get CFBundleSupportedPlatforms:0 || true)"
[ "$PLATFORMS" = "iPhoneOS" ] || fail "CFBundleSupportedPlatforms[0] is '$PLATFORMS', expected iPhoneOS"

FAMILY0="$(plist_get UIDeviceFamily:0 || true)"
[ "$FAMILY0" = "1" ] || fail "UIDeviceFamily[0] is '$FAMILY0', expected 1 (iPhone)"

ICON_NAME="$(plist_get CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName || true)"
[ "$ICON_NAME" = "AppIcon" ] || fail "CFBundleIcons/CFBundlePrimaryIcon/CFBundleIconName is '$ICON_NAME', expected AppIcon"
[ -s "$APP/Assets.car" ] || fail "Assets.car missing or empty (icon archive)"
find "$APP" -maxdepth 1 -name 'AppIcon*.png' | grep -q . || fail "No AppIcon*.png in the app bundle"

REQ_CAPS="$(plist_get UIRequiredDeviceCapabilities || true)"
if echo "$REQ_CAPS" | grep -qi 'armv7'; then
  fail "UIRequiredDeviceCapabilities still lists armv7 while the binary is arm64-only"
fi

if /usr/libexec/PlistBuddy -c "Print :UISupportedDevices" "$PLIST" >/dev/null 2>&1; then
  echo "::warning::UISupportedDevices is present; re-signers normally strip it"
fi

if [ -e "$APP/embedded.mobileprovision" ]; then
  fail "embedded.mobileprovision found in an unsigned build (stale signature/profile)"
fi

if [ -e "$APP/_CodeSignature" ]; then
  echo "::warning::_CodeSignature exists; this IPA is supposed to be unsigned"
fi

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------
EXE="$APP/$EXE_NAME"
[ -f "$EXE" ] || fail "CFBundleExecutable '$EXE_NAME' does not exist"
[ -x "$EXE" ] || fail "Executable bit is not set on '$EXE_NAME'"

echo "::group::Mach-O header"
file "$EXE"
otool -hv "$EXE"
lipo -info "$EXE"
echo "::endgroup::"

ARCHS="$(lipo -archs "$EXE")"
echo "Architectures: $ARCHS"
case " $ARCHS " in
  *" arm64 "*) ;;
  *) fail "Executable does not contain arm64 (found: $ARCHS)" ;;
esac
case " $ARCHS " in
  *x86_64*|*i386*) fail "Executable contains simulator architectures (found: $ARCHS)" ;;
esac

echo "::group::Build version"
xcrun vtool -show-build "$EXE" | tee "$WORK/vtool.txt"
echo "::endgroup::"
grep -q "minos $EXPECTED_MIN_OS" "$WORK/vtool.txt" \
  || fail "LC_BUILD_VERSION minos is not $EXPECTED_MIN_OS"

echo "::group::Linked libraries"
otool -L "$EXE"
echo "::endgroup::"

# Any @rpath/@executable_path/@loader_path dependency must exist inside the app.
BAD_DEPS="$(otool -L "$EXE" | tail -n +2 | awk '{print $1}' | grep -E '^@(rpath|executable_path|loader_path)/' || true)"
if [ -n "$BAD_DEPS" ]; then
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    rel="${dep#@rpath/}"
    rel="${rel#@executable_path/}"
    rel="${rel#@loader_path/}"
    [ -e "$APP/$rel" ] || fail "Linked dylib '$dep' is not embedded in the app"
  done <<< "$BAD_DEPS"
fi

# Anything not under /System or /usr/lib would be a private/absolute path that
# cannot exist on the device.
ODD_DEPS="$(otool -L "$EXE" | tail -n +2 | awk '{print $1}' \
  | grep -Ev '^(/System/|/usr/lib/|@)' || true)"
[ -z "$ODD_DEPS" ] || fail "Unexpected absolute dylib path(s): $ODD_DEPS"

# ---------------------------------------------------------------------------
# Embedded frameworks (none expected today, but fail loudly if one is broken)
# ---------------------------------------------------------------------------
if [ -d "$APP/Frameworks" ] && [ -n "$(find "$APP/Frameworks" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "::group::Embedded frameworks"
  find "$APP/Frameworks" -print
  echo "::endgroup::"
  while IFS= read -r fw; do
    [ -d "$fw" ] || fail "Unexpected non-directory in Frameworks: $fw"
    fw_name="$(basename "$fw" .framework)"
    [ -f "$fw/Info.plist" ] || fail "$fw_name.framework has no Info.plist"
    [ -f "$fw/$fw_name" ] || fail "$fw_name.framework has no executable"
    lipo -archs "$fw/$fw_name" | grep -q arm64 || fail "$fw_name.framework is not arm64"
  done < <(find "$APP/Frameworks" -mindepth 1 -maxdepth 1 -name '*.framework')
fi

# ---------------------------------------------------------------------------
# Swift package resource bundles (YouTubeKit ships JS resources)
# ---------------------------------------------------------------------------
YT_BUNDLE="$APP/YouTubeKit_YouTubeKit.bundle"
[ -d "$YT_BUNDLE" ] || fail "YouTubeKit_YouTubeKit.bundle is missing"
[ -f "$YT_BUNDLE/Info.plist" ] || fail "YouTubeKit_YouTubeKit.bundle has no Info.plist"

echo "::group::YouTubeKit bundle"
plutil -lint "$YT_BUNDLE/Info.plist"
plutil -p "$YT_BUNDLE/Info.plist"
find "$YT_BUNDLE" -type f -print
echo "::endgroup::"

for f in astring.umd.js meriyah.umd.js yt_ejs_helper.js; do
  [ -s "$YT_BUNDLE/$f" ] || fail "YouTubeKit_YouTubeKit.bundle is missing $f"
done

for bundle in "$APP"/*.bundle; do
  [ -d "$bundle" ] || continue
  [ -f "$bundle/Info.plist" ] || fail "$(basename "$bundle") has no Info.plist (cannot be re-signed safely)"
done

# ---------------------------------------------------------------------------
# Junk that breaks re-signing / installation
# ---------------------------------------------------------------------------
if find "$PAYLOAD" \( -name '.DS_Store' -o -name '__MACOSX' -o -name '*.xcuserstate' \) | grep -q .; then
  fail "Found .DS_Store/__MACOSX/xcuserstate inside the IPA"
fi

# ---------------------------------------------------------------------------
# Zip-level checks (permissions survive the zip, executable must be 0755)
# ---------------------------------------------------------------------------
echo "::group::Zip entries"
unzip -Z "$IPA"
echo "::endgroup::"

STRAY="$(unzip -Z1 "$IPA" | grep -v '^Payload/' || true)"
[ -z "$STRAY" ] || fail "IPA contains entries outside Payload/: $STRAY"

MODE="$(unzip -Z "$IPA" | awk -v f="Payload/Sdab.app/$EXE_NAME" '$NF == f { print $1 }')"
echo "Executable mode inside IPA: $MODE"
case "$MODE" in
  -rwx*) ;;
  *) fail "Executable permission was not preserved in the zip (mode: ${MODE:-not found})" ;;
esac

echo ""
echo "Verification passed."
echo "  bundle id : $BUNDLE_ID"
echo "  version   : $SHORT_VERSION ($BUILD_VERSION)"
echo "  min iOS   : $MIN_OS"
echo "  arch      : $ARCHS"
echo "  size      : $(du -h "$IPA" | awk '{print $1}')"
