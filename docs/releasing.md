# Release preparation

MacReady 0.1.1 is the current public release line. These steps remain the
repeatable build, signing, notarization, and release verification workflow.

## Review the release build

From this repository on macOS:

```sh
swift test
swift build -c release --product macready
.build/release/macready --version
.build/release/macready status --json
SKIP_SIGNING=true ./scripts/build-pkg.sh
```

`SKIP_SIGNING=true` produces an unsigned installer containing an ad hoc signed CLI for local review. It is not the public distribution artifact. The default package builds a universal `arm64` + `x86_64` executable; override `ARCHS` only for a deliberately limited local build.

Open `dist/MacReady.pkg` on the author's review machine and check the CLI, shared Skill, and Claude Code compatibility link. Confirm observed state when connecting/disconnecting AC power, opening/closing the lid, and attaching/detaching an external display. Check batteryless and unavailable readings on other hardware when available. Record tested models and macOS versions; a universal build alone does not establish runtime compatibility.

The automated checks cover snapshot parsing, missing values, temperature units, help/error behavior, release build, and package structure. They do not change system power settings or require a real installation. The CI workflow only builds and verifies; it does not publish or notarize.

## Versions and compatibility

Before a release, keep `VERSION`, the version printed in `Sources/MacReadyCLI/MacReadyCommand.swift`, `CHANGELOG.md`, and release documentation aligned. If the CLI's supported semantics change, update its Skill. Review [compatibility](compatibility.md) before changing the JSON schema or `MacStateCore`.

The package reads `VERSION`. Its outputs are:

- `dist/MacReady-VERSION.pkg`: versioned installer.
- `dist/MacReady.pkg`: identical stable filename for distribution links.
- `dist/SHA256SUMS.txt`: SHA-256 checksums.

Environment variables: `DIST_DIR` changes the output directory; `CLI_PATH` supplies a prebuilt CLI; `ARCHS` chooses build architectures; `APP_SIGN_ID` and `PKG_SIGN_ID` select signing identities. Leave `CLI_PATH` unset for the standard universal release build.

## Sign and notarize

Use a Developer ID Application identity for the executable and a Developer ID Installer identity for the package. Override the default author identities when building a fork. Keep signing certificates, private keys, and notarization credentials outside the repository.

```sh
APP_SIGN_ID='Developer ID Application: Your Name (TEAMID)' \
PKG_SIGN_ID='Developer ID Installer: Your Name (TEAMID)' \
./scripts/build-pkg.sh

pkgutil --check-signature dist/MacReady-0.1.1.pkg

NOTARY_PROFILE='your-keychain-profile' ./scripts/notarize-pkg.sh dist
```

The notarization script submits the package with `notarytool --wait`, staples the accepted ticket, updates the stable package copy, and regenerates checksums. Confirm the script succeeds, then validate the final versioned package:

```sh
xcrun stapler validate dist/MacReady-0.1.1.pkg
spctl --assess --type install --verbose=2 dist/MacReady-0.1.1.pkg
(cd dist && shasum -a 256 -c SHA256SUMS.txt)
```

Re-test installation of this exact package on a clean review account or machine before sharing it publicly. Do not upload temporary build directories, component packages, signing material, or local verification snapshots.

## Publish manually

The independent `fuji-mak/MacReady` repository contains the standalone release.
Publish tag `v0.1.1` with the versioned package, `MacReady.pkg`, and
`SHA256SUMS.txt`, then verify the latest-download link and the links to MacReady
and cpsm.

Keep the dated changelog, release download, author attribution, and
Capsomnia/cpsm relationships visible in the README.

Capsomnia Tools may consume the reviewed MacReady executable and this repository's `skills/macready/SKILL.md`. It is a separate signed installer with its own review and notarization. Rebuilding that bundle must use an explicitly selected MacReady version. Capsomnia's main app installer remains separate from both tool installers.
