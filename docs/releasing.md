# Direct distribution and updates

The intended channel is GitHub Releases, not the Mac App Store. The Apple
Developer membership supports Developer ID signing and Apple's notarization.

## Before the first public release
- Create `vladkampov/Inigo` privately, review source and licenses, then choose
  public visibility deliberately. Run `python3 scripts/github-setup.py` to
  inspect commands; `--apply --create-private` creates/configures the private repo.
- GitHub currently blocks branch protection on this account’s private-repository plan. Enable it after public visibility or a plan upgrade. Add a ruleset for main: PR review, passing CI, no force pushes/deletions.
  Solo-maintainer exceptions should be explicit. Set Actions to read-only by default.
- Enable private vulnerability reporting, secret scanning/push protection where
  available, and a protected `github-pages` environment. Establish a private
  security/conduct contact. Publish a stable privacy policy.
- Set up a **Developer ID Application** certificate in Keychain. Apple Development
  is insufficient for direct distribution. Do not commit certificates/private keys.
- Store notarization credentials using `xcrun notarytool store-credentials`;
  use the resulting Keychain profile as INIGO_NOTARY_PROFILE.
- Run Sparkle's `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account app.inigo.updates` once.
  Keep the private key in Keychain, back it up securely, and commit only its public
  key in release/config.json. A dedicated key was generated in the local Keychain during preparation; only its public key is committed. App updates also require INIGO_ENABLE_UPDATES=1 (set by release.sh), so development builds do not contact an unpublished feed.
- Enable GitHub Pages from Actions. The stable appcast URL is
  https://vladkampov.github.io/Inigo/appcast.xml.
- Configure Sentry only if wanted. Reports are off by default and content-free.
  Before adding its public DSN, configure IP removal, retention and access controls,
  update PRIVACY.md and test synthetic ingestion. No DSN means no reporting.
- The repository currently exists privately. Make it public only after release review so distributed Help links are accessible.

## Versioning
VERSION is SemVer; BUILD_NUMBER is a strictly increasing public build number.
Use `python3 scripts/version.py patch` (or minor/major), or `--set 0.3.0-beta.1`.
Update CHANGELOG.md. Use git tags `v<VERSION>`. Never reuse a build number or tag.
CFBundleShortVersionString uses the numeric base; InigoDisplayVersion includes
prerelease metadata. Sparkle orders builds by BUILD_NUMBER.
The old personal timestamp-based builds had no working feed. They are not the
public update baseline; the first public installer starts at build 1.

## Build a release
Set INIGO_SIGN_IDENTITY, INIGO_NOTARY_PROFILE and INIGO_UPDATE_PUBLIC_KEY, then run
`bash scripts/release.sh`. It runs checks, stages a fresh bundle without replacing
your running app, signs nested code inside-out, notarizes, staples, assesses
Gatekeeper and generates an Ed25519-signed archive/appcast. It does not publish.

Keep the bundle identifier stable. Verify source build, third-party notices,
arm64 architecture and framework signing. CloudBridge/Node are excluded.
Model weights download separately.

## Publish only after review
1. Install the notarized archive on a clean Mac with Gatekeeper enabled.
2. Verify Accessibility grant, first download, offline use, shortcuts, Services,
   protected-content fallback, cancellation and exact Undo.
3. Test an update from the previous public signed build: valid update,
   invalid-signature rejection, offline check, disabled automatic checks, skipped
   version and manual installation. Unsigned local builds cannot prove this.
4. Create a **draft** GitHub Release for the tag, attach ZIP and SHA256SUMS,
   and review release notes. Never distribute the ad-hoc development build.
5. Publish the release, then copy the generated appcast.xml into updates/ and
   deploy the Pages workflow. Never publish a feed pointing to a draft/private URL.
   Keep the public feed stable-only; test prereleases on a separate feed.
6. Verify published archive SHA, feed URL, update prompt and clean installation.

Sparkle checks approximately hourly while the app runs; it cannot check while
the Mac sleeps or Inigo is closed. Users can turn checks off and check manually.
Automatic download/install and system profiling are disabled. Archives must pass
Ed25519 validation before extraction; HTTPS and Developer ID are additional layers.
Hosting receives connection metadata, never writing.

## Remaining release gates
- Human multilingual quality review, especially tentative dates and technical names.
- Clean-Mac matrix (M5 Air/Pro, memory tiers, supported macOS versions), Slack,
  Chrome, Safari, Docs and Codex; broad editor support is not yet proven.
- VoiceOver, keyboard-only, reduced-motion and RTL checks.
- Stable signing identity across updates, key backup and actual N→N+1 update test.
- Native-speaker review of the 24 machine-translated UI catalogs.
- Long drafts, low-memory/thermal behavior, download interruption and model errors.
- Public repository/license scan and actionable security reporting route.

Official references:
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/customization/

## CI/CD

See [CI/CD setup](ci-cd.md) for the implemented Release Please workflow, signing
secrets, branch protection and activation steps. Version PR automation is ready;
signed CI builds remain gated until the protected environment and secrets exist.
Public publishing and update-feed deployment remain deliberate review steps.
