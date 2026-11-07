# Inigo for iPhone — phase-one prototype

Separate from the macOS 1.0 milestone. Not ready for TestFlight distribution.

Generate with `xcodegen generate --spec Mobile/project.yml`; open
`Mobile/InigoMobile.xcodeproj`, select InigoMobile and a device. The app embeds
InigoShare. Signing uses the existing team but new identifiers must be registered
by Xcode/account permissions before a real-device install.

Select text → Share → Inigo → edit → Copy & Close → paste manually in the host.
The original is never replaced automatically. The extension accepts one plain-text
provider up to 20,000 UTF-16 units. Unsupported/empty/multiple selections fail
without copying. Copy is explicit and local-only (no Universal Clipboard).
Cancel ends the extension without touching the clipboard. Main-app Paste is also
explicit; there is no background clipboard collection. No drafts are persisted.

This version is deliberately a transport prototype: it does not auto-refine.
The app's Model probe runs a synthetic request with Apple's on-device Foundation
Models, guarded by availability and language support. It reports elapsed time and
uses the same RewriteRequest and ProtectedDraft validators as macOS. The probe
source also compiles into the extension, but extension inference is not yet
exercised. No cloud model or fallback is used. No main-app background server.

## Reused foundation and boundaries

`Sources/InigoCore` is compiled unchanged as a static iOS module: prompts, language
catalog, protected-token validation and text safety. Platform adapters remain
separate. macOS Accessibility, process launching and Sparkle are not linked into
iOS. No App Group entitlement is needed for this first in-memory prototype.
Shared settings/localization/profile integration comes after the round-trip gate.
UI strings in this developer prototype are English, not a localization claim.

## Version policy

macOS retains root VERSION and its existing Release Please/Sparkle workflow.
iOS uses Mobile/VERSION (SemVer) and Mobile/BUILD_NUMBER (strictly increasing across
TestFlight uploads, never reset). App and extension use the same Version.xcconfig.
Run `python3 scripts/mobile-version.py` after edits, `--check` in validation.
Apple marketing version uses the numeric SemVer base; InigoDisplayVersion retains
prerelease metadata. Future iOS tags use `ios/v0.1.0-alpha.1`; they must not trigger
the Mac publisher. TestFlight then App Store; never Sparkle on iOS. Do not automate
upload or stable promotion until device gates pass.

## Device gates

- Test sharing in Slack, WhatsApp, Messages, Mail, Gmail, Safari and Notes where
  offered. Record app/OS versions, payload, host selection/draft retention and
  return behavior. Unsupported sharing uses explicit Paste fallback.
- Verify Copy & Close returns to the host, preserves Unicode/emoji/RTL and writes
  only when tapped. Cancel/load failure must retain a sentinel clipboard value.
- Prove inference inside the extension: availability, supported languages, cold/
  warm latency, peak memory, cancellation, teardown, repeated use, offline and
  thermal behavior. A fast main-app probe is not extension feasibility evidence.
- Only then add automatic refinement, translation with saved target/override,
  original comparison, retries, shared preferences, localization and onboarding.

Reference APIs: Apple NSExtensionContext.completeRequest and
UIPasteboard.OptionsKey.localOnly; Foundation Models SDK availability is checked
at runtime. A 2–5 second target is not a performance claim.

## Validation recorded 2026-11-07

Xcode 27.2 SDK simulator build: app and embedded extension pass. 31 unchanged
InigoCore tests pass on the iPhone 18 Pro / iOS 27.0 simulator. This simulator is
not evidence of either user's physical phone model or OS. Built-bundle validation
confirms both targets report 0.1.0-alpha.1, build 1, and no Sparkle feed/key.
Run `python3 scripts/check-mobile-bundle.py <built-app-path>` after building.
Real host share/copy/dismiss and on-device inference benchmarks remain unverified.
