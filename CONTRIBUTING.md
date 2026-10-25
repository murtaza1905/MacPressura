# Contributing to MacPressura

Thank you for taking the time to contribute. Bug reports, feature ideas, documentation fixes and code are all welcome.

## Reporting a bug

- Open an issue with the **Bug report** template.
- Include your macOS version, whether the Mac is Intel or Apple Silicon, the MacPressura version (shown in the About window) and the exact steps to reproduce.
- For archive problems, name the format (ZIP, 7z, RAR5, TAR.XZ…), how the archive was created if you know, whether it is password-protected, and attach a small archive that reproduces the problem when you can. The engine version is shown under Settings → About.

## Suggesting a feature

- Open an issue with the **Feature request** template.
- Describe the problem you are trying to solve before the solution you have in mind.

## Development setup

Xcode 15 or later. XcodeGen is downloaded into `.tools/` and the 7-Zip engine into `Vendor/7zz/` automatically on the first build; Homebrew is not required.

```bash
git clone https://github.com/murtaza1905/MacPressura.git
cd MacPressura
./scripts/build.sh          # build/MacPressura.app (universal)
./scripts/install.sh        # build, install to /Applications and launch
```

The Xcode project is generated from `project.yml`; it is not committed. To work in Xcode run `./scripts/build.sh` once (or `xcodegen generate`) and open `MacPressura.xcodeproj`. The 7-Zip engine is pinned by version and SHA-256 in `scripts/fetch-7zz.sh`; bumping it means updating both values there. The engine is driven as a child process — `Sources/Engine` owns process control and output parsing, `Sources/Services` the extract/compress use cases and the job queue, `Sources/Views` the SwiftUI interface.

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep each pull request focused on one change.
3. Make sure the project builds with `./scripts/build.sh` — the CI workflow runs the same check on every pull request.
4. Add a line to the **Unreleased** section of `CHANGELOG.md`.
5. Open the pull request; the template lists what to include.

## Code style

- Swift, following Apple's API Design Guidelines; four-space indentation; no trailing whitespace.
- No new third-party dependencies without prior discussion in an issue.
- Every user-facing string goes through the localization layer (`String(localized:)` and `Sources/Resources/Localizable.xcstrings`) and must be provided in both English and Turkish.
- Shell scripts use `set -euo pipefail` and must run on a clean Mac with only Xcode installed.

## Release process (maintainers)

1. Bump the version (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`) and move the **Unreleased** notes in `CHANGELOG.md` under the new version heading.
2. Commit, push to `main` and wait for CI to pass.
3. Start the release in one of two ways:
   - **Actions tab → Release → Run workflow**, enter the version (for example `1.2.0`). The workflow creates and pushes the tag itself.
   - Or tag from Terminal:

     ```bash
     git tag v<version>
     git push origin v<version>
     ```

4. The **Release** workflow builds a universal (Apple Silicon + Intel) app, packages the `.dmg` and `.zip`, writes `SHA256SUMS.txt` and publishes the GitHub Release using the matching `CHANGELOG.md` section as release notes. The version must match the project version or the run stops before building.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
