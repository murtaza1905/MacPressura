<p align="center"><img src="docs/icon.png" width="128" alt="MacPressura icon"></p>

<h1 align="center">MacPressura</h1>

<p align="center">Free, open-source archive utility for macOS.</p>

<p align="center">
  <a href="https://github.com/murtaza1905/MacPressura/actions/workflows/ci.yml"><img src="https://github.com/murtaza1905/MacPressura/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/murtaza1905/MacPressura/releases/latest"><img src="https://img.shields.io/github/v/release/murtaza1905/MacPressura?display_name=tag" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14 or later">
  <img src="https://img.shields.io/badge/Intel%20%7C%20Apple%20Silicon-universal-black" alt="Universal binary">
</p>

MacPressura opens, extracts and creates archives with a native SwiftUI interface on top of the official 7-Zip engine. Everything runs locally: no telemetry, no accounts, no network access at runtime.

<!-- Screenshots: add images to docs/screenshots/ and reference them here. -->

## Features

- **Opens and extracts** ZIP, 7z, RAR (RAR4 / RAR5), TAR, GZ, BZ2, XZ, ZST, LZMA, LZ4, ISO, DMG, CAB, ARJ, LZH, WIM, CPIO, RPM, DEB, XAR/PKG and more
- **Creates** 7z, ZIP, TAR.GZ, TAR.XZ, TAR.BZ2 and TAR — with compression levels, AES-256 passwords and encrypted file names (7z)
- **Drag & drop** onto the window; **Finder "Open With"** for every supported type
- **Smart extraction** (a subfolder unless the archive has a single root item), overwrite policies (rename, skip, overwrite), reveal in Finder when done
- **Task queue** with progress and cancel; several archives in a row without waiting
- **Turkish and English** interface, following the system language
- **Private by design** — no telemetry, no accounts, no network access at runtime

RAR *creation* is intentionally absent: the RAR compressor is proprietary and no open-source tool may produce RAR files.

## Requirements

- macOS 14 Sonoma or later
- Intel or Apple Silicon (one universal binary, engine included)
- Xcode 15 or later, only if you build from source — the prebuilt release needs nothing

## Install

### Download

1. Get `MacPressura-<version>.dmg` from the [latest release](https://github.com/murtaza1905/MacPressura/releases/latest) and drag **MacPressura.app** to **Applications**.
2. The app is ad-hoc signed, not notarized. On first launch right-click the app › **Open**. If macOS reports the app as damaged, run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/MacPressura.app
   ```

3. Every release ships `SHA256SUMS.txt`; verify with `shasum -a 256 -c SHA256SUMS.txt --ignore-missing`.

### Build from source

Only Xcode is required. XcodeGen and the 7-Zip engine are downloaded automatically on the first build; Homebrew is not needed.

```bash
git clone https://github.com/murtaza1905/MacPressura.git
cd MacPressura
./scripts/install.sh
```

The script downloads the pinned 7-Zip engine (SHA-256 verified), generates the Xcode project, builds a universal Release app, installs it to `/Applications`, registers its document types and launches it. Run the same command again to update.

```bash
./scripts/build.sh              # build only → build/MacPressura.app
./scripts/build.sh --clean      # fresh build (drops build products, generated project and cached engine)
./scripts/install.sh            # build, install to /Applications, launch
./scripts/install.sh --no-run   # build and install only
./scripts/make-dmg.sh           # build and package → dist/MacPressura-<version>.dmg
./scripts/uninstall.sh          # remove the app and its settings
```

To work in Xcode: run `./scripts/build.sh` once (or `xcodegen generate` after `scripts/fetch-7zz.sh`), then open `MacPressura.xcodeproj`.

## Usage

- **Open an archive** — drop it on the window, double-click it in Finder (choose MacPressura under *Open With* once) or use ⌘O. The content list shows paths, sizes, dates and whether entries are encrypted.
- **Extract** — use *Extract* in the toolbar; the target follows the *Default target* setting (smart, next to the archive, into a named folder, or ask for a folder). Password-protected archives prompt for the password.
- **Create an archive** — ⌘N or drop files and folders onto the window; pick format, compression level, password and (for 7z) file-name encryption.
- **Tasks** — ⌘J shows the queue with progress and cancel buttons.
- **Settings** (⌘,) — extraction target, overwrite policy, defaults for new archives, Finder reveal options, About.

## Engine

MacPressura drives the official 7-Zip command-line engine (`7zz` by Igor Pavlov), bundled unmodified inside the app at `Contents/MacOS/7zz`. It is fetched at build time from the official GitHub release ([`ip7z/7zip`](https://github.com/ip7z/7zip)) and pinned by version and SHA-256 checksum in `scripts/fetch-7zz.sh`. `Sources/Engine` runs the engine as a child process, assembles its console output and parses the technical listing; `Sources/Services` implements extraction, creation and the job queue on top of it.

## Privacy

MacPressura has no network access, no analytics and no accounts. Preferences live in its own user defaults; archives and extracted files are written only where you choose; passwords are never stored. See [PRIVACY.md](PRIVACY.md).

## Project layout

```
project.yml                     XcodeGen spec (universal, macOS 14+, document types, version)
Sources/App                     App entry, menus, AppDelegate, AboutPanel
Sources/Engine                  7zz process runner, console line assembler, technical listing parser
Sources/Services                Extract / compress services, sequential job queue
Sources/Models                  Formats, entries, jobs, settings
Sources/ViewModels              Main window state
Sources/Views                   SwiftUI views
Sources/Resources               Assets and the TR/EN string catalog
Resources/PrivacyInfo.xcprivacy Privacy manifest
Licenses/7-Zip.txt              7-Zip license text (see THIRD_PARTY_NOTICES.md)
scripts/                        build.sh · install.sh · make-dmg.sh · uninstall.sh · fetch-7zz.sh
.github/workflows/              ci.yml (build check) · release.yml (tag → DMG + ZIP + checksums → GitHub Release)
docs/                           README assets
```

## Roadmap

1. MVP — open, list, extract, create, queue *(0.1.0)*
2. Archive browser — folder tree, selective extraction, drag-out, add/remove files in place
3. Finder integration — Services menu and Quick Actions
4. Advanced — split volumes, solid blocks, test/verify, convert between formats, checksums
5. Signed and notarized builds

## Development

- Build check on every push and pull request: [CI](https://github.com/murtaza1905/MacPressura/actions/workflows/ci.yml).
- Releases are produced by the [Release workflow](.github/workflows/release.yml) from a `v*` tag; see [CONTRIBUTING.md](CONTRIBUTING.md) for the exact steps.
- Changes are tracked in [CHANGELOG.md](CHANGELOG.md).

## Contributing and support

- Bugs and feature ideas: [Issues](https://github.com/murtaza1905/MacPressura/issues) (templates are provided).
- Pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
- Security problems: see [SECURITY.md](SECURITY.md) — please do not open a public issue.

## License

MacPressura is released under the [MIT License](LICENSE).

7-Zip is © Igor Pavlov, licensed under the GNU LGPL with the unRAR restriction and BSD licenses — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [`Licenses/7-Zip.txt`](Licenses/7-Zip.txt).

## Author

Murat Onurcu — [muratonurcu@outlook.com](mailto:muratonurcu@outlook.com)
