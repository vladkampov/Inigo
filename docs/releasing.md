# Direct distribution and updates

The intended channel is GitHub Releases, not the Mac App Store. The Apple
Developer membership supports Developer ID signing and Apple's notarization.

## Current distribution setup
- Source publication review passed on 2026-11-06; repository is public.
- Main ruleset is active: PRs, up-to-date passing CI, resolved conversations,
  linear history, no force pushes/deletions and no bypass actors. Required approvals
  are zero for the solo maintainer; add a reviewer when another maintainer joins.
- Private vulnerability reporting, secret scanning/push protection and Dependabot
  security updates are enabled. The release environment allows only main.
- Signing and notarization credentials are configured and signed CI beta releases
  have passed. Community reports use the GitHub routes described in
  CODE_OF_CONDUCT.md; a dedicated email is not a 1.0 requirement.
  See docs/publication-review.md for remaining gates.
- Set up a **Developer ID Application** certificate in Keychain. Apple Development
  is insufficient for direct distribution. Do not commit certificates/private keys.
- Store notarization credentials using `xcrun notarytool store-credentials`;
  use the resulting Keychain profile as INIGO_NOTARY_PROFILE.
- Run Sparkle's `.build/artifacts/sparkle/Sparkle/bin/generate_keys --account app.inigo.updates` once.
  Keep the private key in Keychain, back it up securely, and commit only its public
  key in release/config.json. A dedicated key was generated in the local Keychain during preparation; only its public key is committed. App updates also require INIGO_ENABLE_UPDATES=1 (set by release.sh), so development builds do not contact an unpublished feed.
- Feeds are hosted on the dedicated `update-feed` branch; GitHub Pages is not used.
  Stable and beta feeds have separate paths. See rollout below.
- Configure Sentry only if wanted. Reports are off by default and content-free.
  Before adding its public DSN, configure IP removal, retention and access controls,
  update PRIVACY.md and test synthetic ingestion. No DSN means no reporting.
- Repository Help links are public. Signed betas and the beta update feed are public.

## Versioning
VERSION is SemVer; BUILD_NUMBER is a strictly increasing public build number.
Use `python3 scripts/version.py patch` (or minor/major), or `--set 0.3.0-beta.1`.
Update CHANGELOG.md. Use git tags `v<VERSION>`. Never reuse a build number or tag.
CFBundleShortVersionString uses the numeric base; InigoDisplayVersion includes
prerelease metadata. Sparkle orders builds by BUILD_NUMBER.
The old personal timestamp-based builds had no working feed. They are not the
public update baseline; CI uses 1000 + the release workflow run number; never reset that sequence.

## Build a release
Set INIGO_SIGN_IDENTITY, INIGO_NOTARY_PROFILE and INIGO_UPDATE_PUBLIC_KEY, then run
`bash scripts/release.sh`. It runs checks, stages a fresh bundle without replacing
your running app, signs nested code inside-out, notarizes, staples, assesses
Gatekeeper and generates an Ed25519-signed archive/appcast. It does not publish.

For an initial beta before feed hosting is configured, set `INIGO_ENABLE_UPDATES=0`.
The archive is still signed for future update verification, but this build does not
contact an unpublished feed. Testers install subsequent builds manually.

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
5. Publish the release with appcast.xml, ZIP and SHA256SUMS attached. The feed
   workflow verifies the archive and publishes to the matching channel. Never publish a feed pointing to a draft/private URL.
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
- Stable-channel promotion and key backup; beta.6 → beta.7 installation passed.
- Native-speaker review of the 24 machine-translated UI catalogs.
- Long drafts, low-memory/thermal behavior, download interruption and model errors.
- Public repository/license scan and actionable security reporting route.

Official references:
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/customization/

## CI/CD

See [CI/CD setup](ci-cd.md) for the implemented Release Please workflow, signing
secrets, branch protection and activation steps. Version PR automation and signed, notarized CI builds are operational.
Public release publication remains deliberate; feed deployment follows publication.

## Beta update rollout

Beta.5 was published with updates disabled. It requires one manual upgrade to the
first update-enabled beta; it cannot discover a new feed retroactively. New beta
builds use `/beta/appcast.xml`, with hourly checks, no automatic installation and
no system profiling. The feed workflow verifies the highest published beta's
checksum and Ed25519 signature and deploys after publication. Stable builds use
the separate `/stable/appcast.xml` endpoint, which is not yet live.
The publisher fails closed if there is no published signed stable release; it never
substitutes a beta. Draft releases and mismatched prerelease flags are excluded.

On 2026-11-06, the actual Sparkle update from beta.6 (1018) to beta.7 (1020)
passed: prompt, download, installation, relaunch, retained shortcut and update
preferences, installed version, code signature and Gatekeeper assessment. The
check was manual; the hourly schedule is configured but was not timed end to end.

Beta feed endpoint: `https://raw.githubusercontent.com/vladkampov/Inigo/update-feed/beta/appcast.xml`. The dedicated update-feed branch avoids dependency on personal-domain DNS. Publishing rejects lower build numbers or changed artifacts for the same build.

Stable endpoint: `https://raw.githubusercontent.com/vladkampov/Inigo/update-feed/stable/appcast.xml`.
Before 1.0, change Release Please out of beta/prerelease mode in a reviewed PR,
prepare the stable version and notes, then run the same signing and verification
gates. Do not mark a beta artifact stable: its embedded update URL stays beta.
Test beta-to-stable migration explicitly before promising automatic migration.
A manual publisher run accepts `--channel beta` or `--channel stable`.
