# Counseling IS

An offline-first Flutter application for school counseling and Care Center
records. The Windows app stores its data in a local SQLite database.

## Features

- Dashboard overview with student, intervention and appointment counts,
  plus today's guidance queue
- Administrator sign-in with multiple bcrypt-protected accounts, auto-lock
  after inactivity, failed-attempt throttling, and account management
- Student records with generated reference numbers (`CLI-YYYY-NNNN`);
  students are archived, never deleted
- Appointment scheduling with overlap checks, statuses and calendar views
- Guidance calendar for scheduled appointments
- Confidential counseling session records — notes never appear in lists
  or reports
- Intervention plans with individual or group student links, progress status,
  target dates, and outcomes; custom intervention types can be specified
- Student forms (11 templates plus a confidential child-protection intake
  workflow) with PDF export and system printing
- Batch fill: merge several student forms into one page, fill them together
  and save them as a single grouped batch
- Saved forms grouped by student: one row per student, whose name opens a
  print-ready preview of every form saved for them
- Any student's Individual Student Information Sheet can be previewed and
  printed straight from the Students list or their detail window, filled from
  the record itself — no saved form required. The preview fills the actual
  Word template and renders it through Microsoft Word when it is available,
  so the sheet keeps the exact DepEd layout, logos and typography; the
  built-in PDF renderer is used as a fallback when Word is unavailable
- Searchable audit log for account and record changes; confidential form
  contents and counseling notes are not copied into audit details
- Reports for students, appointments and sessions with date-range
  and status filters, exported as CSV or PDF and printable from an
  in-app preview
- An aggregate DepEd services report draft; it is **not** an official DepEd
  form and must be checked against the current division-prescribed template
- Database backup and restore: consistent snapshots, validated before a
  restore, with an automatic application restart afterwards
- Settings: configurable auto-lock timeout, database and schema
  information

## Student forms

The **Student Forms** section digitizes the 11 provided templates:

- Student Information Sheet and Counseling Intake Form
- Individual Counseling Record and Referral Form
- Home Visit Report and Follow-up Monitoring Sheet
- Parent / Guardian Conference Report and Testing Service Log
- Monthly Accomplishment Report and Informed Consent for Counseling Services
- Care Center Visit Log Sheet

Saved form records can be edited, searched, filtered by form type, and
optionally linked to a student. Form records are stored in the local database
and included in database backups.

The list itself groups linked records by student, so a name is never repeated
across rows. Clicking the student's name opens a preview window with all of
that student's forms combined into one print-ready PDF, ready to print or
share, with the per-form open and delete actions moved into that window.
Records saved without a student keep their own row. The Forms cell lists only
the newest form and collapses the rest into a **+N more** link that opens
the same preview, so a row stays one line tall no matter how many forms a
student has.

### Batch fill

**Batch fill** (sidebar) fills several templates for one student on a single
merged page. Shared student details — name, grade & section, sex, age,
address, parent/guardian contact — appear once at the top; each chosen form's
own sections follow under a `<document number> · <title>` banner. One **Save
all** action writes separate records grouped under a shared batch id, skips
forms left blank, and updates an existing record for the same student and
form instead of duplicating it. Batches can be reopened from **Saved
batches**, and **Save as PDF** exports the whole batch as one combined PDF
(the Word exact-layout print stays per form and is hidden in batch mode).
The confidential Child Protection Intake and the retired CC Form 1 are not
offered in the batch picker.

The separate Child Protection Intake workflow is an internal intake aid, not
an official DepEd DO 40 s. 2012 form. It is marked confidential; follow current
school and division protocols and record only the information needed for a
safe response.

The source set uses the label “CC Form 9” for both the monthly report and
informed consent; the app distinguishes them by title.

Use the print icon on a provided form page to create a PDF from the current
answers and open the system print dialog. The PDF layout is rendered by the app
and follows each form's page size and orientation; line wrapping and pagination
may differ from the supplied Word references. The child-protection intake
workflow has no official source template, so its PDF is clearly marked as an
internal workflow and not an official DepEd form.

## Getting started

### Requirements

- Flutter SDK (developed with Flutter 3.47.x / Dart 3.13)
- Windows 10 or 11 for the desktop app
  (macOS is untested — see [docs/MACOS_BUILD.md](docs/MACOS_BUILD.md))

### Run in development

```shell
flutter pub get
flutter run -d windows
```

### Build a release copy

```shell
flutter build windows --release
```

The executable is written to `build\windows\x64\runner\Release\`.

### Build a Windows installer

One-time setup — install Inno Setup 6:

```shell
winget install --id JRSoftware.InnoSetup -e
```

Then build the installer:

```shell
powershell -ExecutionPolicy Bypass -File scripts\build_windows_installer.ps1
```

The per-user installer (no admin rights required) is written to
`build\windows\installer\CounselingIS-Setup-<version>.exe`. It installs
to `%LOCALAPPDATA%\Programs\Counseling IS` with a Start Menu shortcut,
an optional desktop icon and a full uninstaller. The build verifies the PDF
fonts and form branding assets are in the release bundle before packaging.
Windows builds are also available as a downloadable artifact from the
`Windows Installer` GitHub Actions workflow.

### Build a macOS installer

On a Mac (macOS cannot be built from Windows):

```shell
scripts/build_macos_installer.sh
```

The drag-to-Applications installer is written to
`build/dmg/Counseling IS-<version>.dmg`. The build verifies the PDF fonts and
form branding assets are in the release bundle before packaging. Signing and
notarization options are documented in
[docs/MACOS_BUILD.md](docs/MACOS_BUILD.md).

No Mac handy? Pushing to `main` runs the same packaging script on a
GitHub Actions macOS runner; download the `Counseling-IS-macOS-installer`
artifact from the workflow run (unsigned test build — see
[docs/MACOS_BUILD.md](docs/MACOS_BUILD.md)).

### Analyze and test

```shell
flutter analyze
flutter test
```

## Data and storage

- The database is a single SQLite file, created on first run:
  `%APPDATA%\com.example\counseling_is\counseling.db` on Windows
- Existing case-management and violation records are retained in the database
  and in backups, but are no longer shown or managed in the app
- The application is fully offline; no data leaves the computer
- Database backups written from the app are **not encrypted** — store
  them securely
- Schema changes are applied automatically through numbered migrations
  when a newer version of the app opens an older database
- To reset everything: close the app and delete the database file; the
  next start runs first-time setup again

## Security notes

- Passwords are hashed with bcrypt (cost factor 12) and are never stored
  in plain text
- The session locks automatically after a configurable period of
  inactivity and can be locked manually; a locked session requires the
  password to unlock
- Sign-in is throttled after repeated failed attempts
- Confidential session notes are deliberately excluded from reports and
  exports
- SQLCipher is not used; the database relies on the operating system's
  file permissions and full-disk encryption for at-rest protection

## Project structure

```
lib/core      database (migrations, SQLite), security, theme, shared widgets, CSV export
lib/features  auth, clients, appointments, sessions, forms,
              dashboard, reports, backup, settings
lib/shell     navigation shell
test/         repository, service and widget tests
```

## Platform support

- **Windows** — built and tested (debug and release) on Windows 11
- **macOS** — platform folder, plugins and sandbox entitlements are
  configured (user-selected file access, printing), but the app has
  **not** been built or tested on macOS; see
  [docs/MACOS_BUILD.md](docs/MACOS_BUILD.md) before attempting it
