# macOS build notes

**Status: not built yet.** This project was developed and tested entirely
on Windows 11 (Flutter 3.47.x, Dart 3.13). The macOS project files exist,
the plugins are registered, and the App Sandbox entitlements needed for
file save/open and printing have been added, but no one has built, run or
tested the app on a Mac. Treat the steps below as a starting point, not as
a working guarantee.

## Entitlements

Both `macos/Runner/DebugProfile.entitlements` and
`macos/Runner/Release.entitlements` contain:

- `com.apple.security.files.user-selected.read-write` — required by
  `file_selector` save/open dialogs under the App Sandbox (DOCX, CSV and
  PDF export, backup restore). Without it the panel opens but the file
  cannot be written or read.
- `com.apple.security.print` — required for the system print dialog used
  by report printing. Without it macOS shows "Printing Not Allowed".

If the platform folder is ever regenerated, re-apply these keys to both
files.

## What should carry over

All packages used by the app declare macOS support:

- `sqflite_common_ffi` — uses the system SQLite through Dart FFI; macOS
  ships SQLite, so no extra native library is expected
- `bcrypt`, `provider`, `go_router`, `intl`, `uuid` — pure Dart
- `file_selector`, `path_provider` — official plugins with macOS
  implementations
- `pdf`, `printing`, `csv` — `printing` supports macOS via the system
  print dialog
- Student Forms renders a PDF in-app, saves it, and opens the system print
  dialog. The generated PDF uses the corresponding form's paper size and
  orientation; exact Word pagination is not guaranteed.

## Steps to try

1. On a Mac with Flutter installed:

   ```shell
   flutter pub get
   flutter run -d macos
   ```

2. If platform folders are ever missing, regenerate them:

   ```shell
   flutter create --platforms=macos --org com.example --project-name counseling_is .
   ```

   (This must not overwrite `lib/`, `test/` or `pubspec.yaml`.)

3. Build a release app bundle:

   ```shell
   flutter build macos
   ```

## Building an installer (.dmg)

The repository contains a packaging script that produces a
drag-to-Applications installer. On a Mac, from the repository root:

```shell
scripts/build_macos_installer.sh
```

It runs `flutter build macos --release`, verifies that the signed app
contains the sandbox entitlements, then packages it with an
`/Applications` symlink into:

```
build/dmg/Counseling IS-<version>.dmg
```

### Building on GitHub Actions

The `.github/workflows/macos-installer.yml` workflow runs the same
packaging script on a `macos-latest` runner whenever changes are pushed
to `main` (or manually via `workflow_dispatch`). It publishes a
`Counseling-IS-macOS-installer` artifact containing the DMG, kept for
30 days. Download it from the run summary at:

`https://github.com/dondonmarcosbusiness-ui/counseling_IS/actions`

A separate parallel job runs `flutter analyze` and `flutter test`.

The CI artifact is unsigned and not notarized (no Apple certificate is
available to the runner), so Gatekeeper will block it on other Macs.
Open the app with right-click → Open, or clear the quarantine flag:

```shell
xattr -dr com.apple.quarantine /Applications/counseling_is.app
```

Use fictional data only with CI builds.

### Distributing to other Macs

An unsigned build only runs on the machine that created it (Gatekeeper
blocks it elsewhere). For real distribution, export the two optional
variables first:

```shell
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="counseling-is"   # create once with notarytool
scripts/build_macos_installer.sh
```

Create the notary profile once per machine:

```shell
xcrun notarytool store-credentials counseling-is \
  --apple-id you@example.com --team-id TEAMID
```

With those set, the script re-signs with hardened runtime, submits the
app and the dmg for notarization, and staples the tickets so Gatekeeper
accepts the download without warnings.

Check a built app with:

```shell
spctl --assess --type open -vv "build/macos/Build/Products/Release/counseling_is.app"
```

Without an Apple Developer account the only options are running the app
on your own Mac, or clearing the quarantine flag on the target machine
(`xattr -dr com.apple.quarantine /Applications/counseling_is.app`).

## Expected differences from Windows

- **Data location**: `path_provider`'s application-support directory on
  macOS resolves to
  `~/Library/Application Support/com.example/counseling_is/counseling.db`
  instead of `%APPDATA%`. The app itself shows the resolved path in
  Settings → About.
- **Printing** opens the macOS print dialog; the in-app report preview
  behaves the same as on Windows.
- **Form printing**: Student Forms saves the generated PDF and opens the
  macOS print dialog; the PDF remains available at the selected save path.
- **Restore restart**: after a backup restore the app relaunches itself;
  if the OS blocks the relaunch, the app asks the user to close and
  reopen it manually instead of exiting silently.
- **Code signing**: running from Flutter tooling works with ad-hoc
  signing; distributing outside the App Store requires a proper signing
  identity and notarization.
- **Gatekeeper**: a locally built `.app` may need
  `xattr -dr com.apple.quarantine` if macOS refuses to open it.

## If something fails

The most likely failure points on macOS are native plugin registration
(printing, file selector) and SQLite FFI loading. Check
`flutter doctor -v`, and verify that `macos/Flutter/GeneratedPluginRegistrant.swift`
lists the plugins after `flutter pub get`. Please report any macOS-specific
failure separately — it has not been exercised by this project.
