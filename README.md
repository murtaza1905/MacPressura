# MacPressura

Açık kaynak, ücretsiz bir macOS arşiv uygulaması
Open-source, free archive utility for macOS

- Opens and extracts: ZIP, 7z, RAR (RAR4 / RAR5), TAR, GZ, BZ2, XZ, ZST, LZMA, LZ4, ISO, DMG, CAB, ARJ, LZH, WIM, CPIO, RPM, DEB, XAR/PKG and more
- Creates: 7z, ZIP, TAR.GZ, TAR.XZ, TAR.BZ2, TAR — with compression levels, AES-256 passwords and encrypted file names (7z)
- Drag & drop, Finder "Open With", smart extraction, overwrite policies, a task queue with progress and cancel
- Turkish and English interface
- Everything runs locally. No telemetry, no accounts, no network access at runtime.

RAR *creation* is intentionally absent: the RAR compressor is proprietary and no open-source tool may produce RAR files.

## Kurulum / Install

Xcode must be installed (App Store). Then:

```bash
git clone https://github.com/murtaza1905/MacPressura.git ~/MacPressura
cd ~/MacPressura && ./build.sh
```

`build.sh` downloads XcodeGen and the official 7-Zip engine (`7zz`, universal binary, SHA-256 verified), generates the Xcode project, builds a Release universal app, installs it to `/Applications` and launches it. Nothing else needs to be installed; Homebrew is not required.

Options: `./build.sh --no-run` (build and install only), `./build.sh --clean` (fresh build).

## Engine

MacPressura drives the official 7-Zip command-line engine (`7zz` by Igor Pavlov), bundled unmodified inside the app. It is fetched at build time from the official GitHub release (`ip7z/7zip`) and pinned by version and checksum in `scripts/fetch-7zz.sh`.

## Project layout

```
project.yml            XcodeGen spec (universal, macOS 14+)
build.sh               one-shot build + install + launch
scripts/fetch-7zz.sh   pinned 7zz download with SHA-256 verification
Sources/App            app entry, menus, AppDelegate
Sources/Engine         7zz process runner, console line assembler, technical listing parser
Sources/Services       extract / compress services, sequential job queue
Sources/Models         formats, entries, jobs, settings
Sources/ViewModels     main window state
Sources/Views          SwiftUI views
Sources/Resources      assets and the TR/EN string catalog
```

## Roadmap

1. MVP — open, list, extract, create, queue (this release)
2. Archive browser — folder tree, selective extraction, drag-out, add/remove files in place
3. Finder integration — Services menu and Quick Actions
4. Advanced — split volumes, solid blocks, test/verify, convert between formats, checksums
5. Release — signed builds, GitHub Releases

## License

MacPressura is released under the MIT License (see `LICENSE`).
7-Zip is © Igor Pavlov, licensed under the GNU LGPL with the unRAR restriction and BSD licenses (see `LICENSE-7zip`).
