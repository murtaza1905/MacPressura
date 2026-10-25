# Security Policy

## Supported versions

Only the latest release on the [Releases](https://github.com/murtaza1905/MacPressura/releases/latest) page receives fixes. Please update before reporting a problem.

## Reporting a vulnerability

Please do **not** open a public issue for security problems.

Email **muratonurcu@outlook.com** with:

- a description of the issue and its impact,
- steps to reproduce or a proof of concept,
- the MacPressura version and macOS version you tested on.

You will receive an acknowledgement within 7 days. Once the issue is confirmed, a fix is prepared and published as a new release, and the report is credited in `CHANGELOG.md` unless you prefer to stay anonymous.

## Security model

- MacPressura runs entirely on your Mac and needs no special permissions. It reads and writes only the files and folders you open, drop or choose in a dialog.
- The archive engine is the official 7-Zip command-line binary (`7zz`), downloaded at build time from the official GitHub releases, verified against a SHA-256 checksum pinned in `scripts/fetch-7zz.sh` and bundled unmodified inside the app. It runs as a child process of the app.
- Extraction uses 7-Zip's own path handling; archives are never executed, only unpacked. Overwrite behaviour is controlled by the policy in Settings.
- Passwords you type are passed to the engine for the current task only and are not stored anywhere.
- There is no network code at runtime, no helper and no background process. Releases are built by GitHub Actions from the tagged commit; the workflow is in `.github/workflows/release.yml` and every build log is public.

## Verifying downloads

Every release ships a `SHA256SUMS.txt` file. To verify a download:

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS.txt --ignore-missing
```
