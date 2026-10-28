# Changelog

All notable changes to MacPressura are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- App icon now follows the standard macOS icon template (824 px body with margins and drop shadow), so macOS 26 displays it directly instead of shrinking it onto a backing plate.

## [0.1.0] - 2026-10-25

First public build (MVP).

### Added
- Opens and extracts ZIP, 7z, RAR (RAR4 / RAR5), TAR, GZ, BZ2, XZ, ZST, LZMA, LZ4, ISO, DMG, CAB, ARJ, LZH, WIM, CPIO, RPM, DEB, XAR/PKG and more, through the bundled 7-Zip engine (`7zz` 26.05, universal, pinned by SHA-256).
- Creates 7z, ZIP, TAR.GZ, TAR.XZ, TAR.BZ2 and TAR archives with compression levels, AES-256 passwords and encrypted file names (7z).
- Drag & drop, Finder "Open With" for all supported archive types, smart extraction target, overwrite policies, sequential task queue with progress and cancel.
- Turkish and English interface following the system language.
- **About MacPressura** in the application menu (standard About window with developer contact, source link and engine credit) and an About section in Settings.
- Privacy manifest (`PrivacyInfo.xcprivacy`) bundled with the app.
- `scripts/build.sh`, `scripts/install.sh`, `scripts/make-dmg.sh`, `scripts/uninstall.sh`; XcodeGen and the engine are downloaded automatically, no Homebrew needed.
- Continuous integration build on every push and pull request; tag-triggered release workflow that builds the universal app, packages `.dmg` and `.zip`, writes `SHA256SUMS.txt` and publishes the GitHub Release.
- `CONTRIBUTING.md`, `SECURITY.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`, issue and pull request templates.

### Changed
- Hardened runtime enabled for the app bundle.
- The 7-Zip license text moved from `LICENSE-7zip` to `Licenses/7-Zip.txt` so that the repository's own license (MIT) is detected correctly.

[Unreleased]: https://github.com/murtaza1905/MacPressura/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/murtaza1905/MacPressura/releases/tag/v0.1.0
