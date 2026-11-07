# Inigo for iPhone

Native companion app and Share extension, developed separately from macOS 1.0.
Current development build: 0.1.0-alpha.1 (3). Not yet a public/TestFlight release.

## Current behavior

Select text → Share → Inigo → automatic on-device refinement → review/edit →
Copy & Close → manually paste in the host app. The app also offers explicit Paste,
which starts refinement. Inigo never sends messages or replaces host drafts itself.

Translate opens a language menu and remembers the chosen target in the current
app/extension preferences. Apple Foundation Models availability and source/target
language support are checked; unsupported languages show an error and preserve
text. No cloud fallback exists. Target preferences are not yet synchronized between
app and extension: App Group storage is a separate integration gate.

Original comparison, guarded Undo, cancellation and editing during generation are
supported. Typing cancels the pending result; late results cannot overwrite new
text. A 45-second limit abandons the result. Copy is explicit, local-only and
disabled during generation. Cancel and failures do not write to the clipboard.
Plain-text sharing cannot reconstruct functional mentions or rich objects.

## Reusable foundation

The same InigoCore sources provide rewrite prompts, language identifiers, protected
markers and text-safety checks. The mobile adapter uses Apple's on-device model;
macOS Accessibility, process launching and Sparkle remain outside iOS. The shared
TranslationQuality implementation rejects confident wrong-language output.
No drafts, results or conversations are persisted. No App Group entitlement yet.
The synthetic probe remains in Benchmarks as developer scaffolding, not user UI.

## Build and versioning

Run `python3 scripts/mobile-version.py`, then
`xcodegen generate --spec Mobile/project.yml`. Open InigoMobile.xcodeproj and select
InigoMobile plus a device. Both targets use the same development team and automatic
signing; registering a device/profile requires account authorization.

Mobile/VERSION is independent SemVer. Mobile/BUILD_NUMBER increases across uploads
and is never reset. Generated Version.xcconfig drives both app and extension.
Apple marketing version uses the numeric base; InigoDisplayVersion preserves the
prerelease. Run `scripts/check-mobile-bundle.py <built-app>` to verify alignment.
Future mobile release tags use `ios/v…`; existing Mac Release Please/Sparkle remains
unchanged. TestFlight first, then App Store. No mobile upload automation yet.

## Device checks

1. Share synthetic Notes text including emoji; verify it appears, refines, and keeps
   tentative language. Edit and Copy & Close; paste manually in a scratch note.
2. Choose a supported translation language; check meaning and actual language.
   Try an unsupported language and confirm the original remains intact.
3. Start refinement, type immediately, then wait: your edit must remain.
4. After a rewrite, Undo restores the exact previous text. After further edits,
   Undo must not overwrite them. Original shows the initial shared/pasted text.
5. With a clipboard sentinel, cancel or provoke a model error; the sentinel must
   remain. Repeat invocation, dismiss during processing and test offline.
6. Repeat in each host where text sharing is offered; record exact host/iOS version,
   return behavior and fallback needs. Never use private work content.

## Evidence and remaining gaps

Build 2: 35 iOS core/share tests passed. Build 3 adds controller tests for automatic
refinement, failures, typing cancellation despite late output and guarded Undo.
Simulator tests do not prove real Foundation Models quality, latency, memory,
thermal behavior or extension lifecycle limits; these require physical testing.
The physical development build/install workflow is verified. The owner confirmed
Notes text appears after the build-2 share-loader fix. Rich-editor host coverage,
localization, shared settings, personalization and distribution remain incomplete.
UI language currently English; do not claim complete macOS feature parity.
