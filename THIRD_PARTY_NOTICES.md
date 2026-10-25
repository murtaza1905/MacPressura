# Third-party notices

MacPressura bundles the following third-party software. Its license and copyright notice are reproduced here as required.

## 7-Zip (`7zz`, macOS command-line version)

- Author: Igor Pavlov — https://7-zip.org
- Version and checksum: pinned in `scripts/fetch-7zz.sh`; downloaded at build time from the official releases at https://github.com/ip7z/7zip and bundled **unmodified** as `MacPressura.app/Contents/MacOS/7zz`.
- License: GNU LGPL v2.1 (most of the code), BSD 3-clause (some parts), and the **unRAR restriction** for the RAR decompression code. The full text is in [`Licenses/7-Zip.txt`](Licenses/7-Zip.txt).

The unRAR restriction is why MacPressura can open and extract RAR archives but cannot create them: the RAR decompression source may not be used to re-create the RAR compression algorithm.

## Build tooling (not distributed with the app)

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (MIT) — downloaded by `scripts/build.sh` at build time to generate the Xcode project.
