# Privacy Policy

**MacPressura** — last updated 25 October 2026

MacPressura is a free, open-source macOS application developed by Murat Onurcu. This policy describes what the application does with data on your Mac.

## Summary

MacPressura does not collect, store, transmit or share any personal data. It has no user accounts, no analytics, no advertising, no crash reporting service and no network access at runtime.

## Data stored on your Mac

- Preferences (default extraction target, overwrite policy, default format and compression level, Finder reveal options) in the application's user defaults (`com.muratonurcu.MacPressura`). They can be removed with `scripts/uninstall.sh` or `defaults delete com.muratonurcu.MacPressura`.
- The archives you open and the files you extract or compress are read and written where you choose; MacPressura keeps no copies, history or index of them.
- Passwords typed for encrypted archives are used for the current task only and are never stored.

All of this stays on your Mac. Nothing is uploaded anywhere.

## Data that leaves your Mac

None. MacPressura never opens a network connection. It does not check for updates; new versions are announced only on the GitHub Releases page.

## Permissions

MacPressura requests no permissions. Access to files follows the standard macOS rules for files you open, drop onto the app or select in a dialog; macOS may ask once before the app reads a protected folder such as Desktop, Documents or Downloads.

## Third-party components

- **7-Zip (`7zz`)** by Igor Pavlov, bundled unmodified as the archive engine. It processes files locally and has no network functionality. License: GNU LGPL with the unRAR restriction — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

No analytics SDKs, no advertising SDKs, no crash reporters.

## Children's privacy

MacPressura does not collect data from anyone, including children.

## Changes to this policy

Changes are recorded in this file and in `CHANGELOG.md`. The version history of this document is available in the repository.

## Contact

Murat Onurcu — muratonurcu@outlook.com
