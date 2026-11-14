#!/usr/bin/env bash
#
# Builds a macOS installer (.dmg) for Counseling IS.
#
# Usage:
#   scripts/build_macos_installer.sh
#
# Must run on a Mac with Flutter installed, from this repository.
#
# Optional environment variables:
#   CODESIGN_IDENTITY   Developer ID Application certificate, e.g.
#                       "Developer ID Application: Jane Doe (TEAMID1234)".
#                       The app is re-signed with hardened runtime and the
#                       Release entitlements. Without it, the local
#                       signature produced by the Flutter tool is kept
#                       (runs on your own Mac, Gatekeeper warnings on others).
#   NOTARY_PROFILE      notarytool keychain profile name. Notarizes and
#                       staples the app and the dmg. Requires
#                       CODESIGN_IDENTITY. Create the profile once with:
#                       xcrun notarytool store-credentials <name> \
#                         --apple-id you@example.com --team-id TEAMID1234
#   DMG_DIR             Output directory (default: build/dmg).

set -euo pipefail

APP_PRODUCT_NAME="counseling_is"
APP_DISPLAY_NAME="Counseling IS"
ENTITLEMENTS="macos/Runner/Release.entitlements"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ "$(uname -s)" == "Darwin" ]] || die "this script must run on macOS"
command -v flutter >/dev/null 2>&1 || die "flutter not found on PATH"
command -v hdiutil >/dev/null 2>&1 || die "hdiutil not found (required on macOS)"
[[ -f pubspec.yaml ]] || die "pubspec.yaml not found; run from the repository"
[[ -f "$ENTITLEMENTS" ]] || die "missing $ENTITLEMENTS"
[[ -z "${NOTARY_PROFILE:-}" || -n "${CODESIGN_IDENTITY:-}" ]] \
  || die "NOTARY_PROFILE requires CODESIGN_IDENTITY"

VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1)"
VERSION="${VERSION%%+*}"
[[ -n "$VERSION" ]] || die "could not read version from pubspec.yaml"

APP_DIR="build/macos/Build/Products/Release"
APP="$APP_DIR/$APP_PRODUCT_NAME.app"
DMG_DIR="${DMG_DIR:-build/dmg}"
DMG="$DMG_DIR/$APP_DISPLAY_NAME-$VERSION.dmg"

log "Building release app (version $VERSION)"
flutter pub get
flutter build macos --release
[[ -d "$APP" ]] || die "expected app not found at $APP"
# Newer Flutter releases embed flutter_assets inside App.framework;
# older layouts keep them under Contents/Resources.
if [[ -d "$APP/Contents/Frameworks/App.framework/Resources/flutter_assets" ]]; then
  FLUTTER_ASSETS="$APP/Contents/Frameworks/App.framework/Resources/flutter_assets"
else
  FLUTTER_ASSETS="$APP/Contents/Resources/flutter_assets"
fi
[[ -d "$FLUTTER_ASSETS" ]] || die "flutter_assets not found in $APP"
for asset in \
  assets/forms/branding/carranglan_school_seal.png \
  assets/forms/branding/deped_seal.png \
  assets/forms/branding/deped_matatag_banner.jpg \
  assets/fonts/roboto-regular.ttf \
  assets/fonts/roboto-bold.ttf; do
  [[ -f "$FLUTTER_ASSETS/$asset" ]] \
    || die "required PDF asset missing from macOS release: $asset"
done

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  log "Signing with: $CODESIGN_IDENTITY"
  if [[ -d "$APP/Contents/Frameworks" ]]; then
    while IFS= read -r -d '' item; do
      codesign --force --options runtime --timestamp \
        --sign "$CODESIGN_IDENTITY" "$item"
    done < <(find "$APP/Contents/Frameworks" -depth \
              \( -name '*.framework' -o -name '*.dylib' \) -print0)
  fi
  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$CODESIGN_IDENTITY" "$APP"
else
  log "No CODESIGN_IDENTITY set - keeping the local signature"
fi

log "Verifying signature and entitlements"
codesign --verify --deep --strict "$APP"
SIGNED_ENTITLEMENTS="$(codesign -d --entitlements - "$APP" 2>&1 || true)"
for key in com.apple.security.files.user-selected.read-write \
           com.apple.security.print; do
  grep -q "$key" <<<"$SIGNED_ENTITLEMENTS" \
    || die "entitlement missing from signed app: $key"
done
log "Entitlements verified"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  log "Notarizing app"
  ZIP="$APP_DIR/$APP_PRODUCT_NAME.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "$ZIP"
fi

log "Creating installer: $DMG"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$DMG_DIR"
rm -f "$DMG"
hdiutil create -volname "$APP_DISPLAY_NAME $VERSION" \
  -srcfolder "$STAGE" -ov -format UDZO "$DMG"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  log "Notarizing dmg"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

log "Done"
printf 'Installer: %s\nSHA-256:  %s\n' \
  "$DMG" "$(shasum -a 256 "$DMG" | awk '{print $1}')"
