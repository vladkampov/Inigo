# Inigo for iPhone

Native companion app and Share extension, developed separately from macOS 1.0.
Current development build: 0.1.0-alpha.1 (6). Not yet a public/TestFlight release.

## Current behavior

Select text → Share → Inigo → automatic on-device refinement → review/edit →
Copy & Close → manually paste in the host app. The app also offers explicit Paste,
which starts refinement. Inigo never sends messages or replaces host drafts itself.

Translate opens a language menu and remembers the chosen target in the current
shared preferences. Refinement checks Apple Foundation Models availability. Translation uses Apple’s
separate Translation framework with downloaded low-latency language packs; unsupported
language pairs show an error and preserve text. No cloud fallback exists. The app and extension share settings through an App Group. Changes are read fresh
under a cross-process lock; device round-trip verification remains pending.

Original comparison, guarded Undo, cancellation and editing during generation are
supported. Typing cancels the pending result; late results cannot overwrite new
text. A 45-second limit abandons the result. Copy is explicit, local-only and
disabled during generation. Cancel and failures do not write to the clipboard.
Plain-text sharing cannot reconstruct functional mentions or rich objects.

## Reusable foundation

The same InigoCore sources provide rewrite prompts, language identifiers, protected
markers and text-safety checks. The mobile adapters use Apple’s on-device writing model and dedicated translation packs;
macOS Accessibility, process launching and Sparkle remain outside iOS. The shared
TranslationQuality implementation rejects confident wrong-language output.
No drafts, results or conversations are persisted. Only compact style counters and preferences are saved in the App Group; drafts
and results stay in memory. No cross-device/macOS synchronization is enabled.
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
distribution and real-device shared settings verification remain incomplete.
Do not claim complete macOS feature parity.

## Language and personal style

24 interface languages follow the iPhone language by default, with an override in
Settings. Translation target and learning settings are shared with the Share sheet.
RTL interfaces use right-to-left layout; editor text retains natural direction.
Interface language coverage does not imply Apple model support for every language.
Translations were generated locally and need native-speaker review.

Learning uses explicit copies of changed refinements as weak evidence. Only
closed-vocabulary counters are stored per language; translations do not train style.
Repeated evidence activates a preference. Inspect, pause, or reset it in Settings.
Pausing stops learning and retains existing preferences. Nothing syncs to a server.

Run `python3 scripts/mobile-localizations.py` before generating the Xcode project;
`--check` validates complete catalogs and packaged resources without modifying them.

## Build 4 evidence and TestFlight gates

- 44 iOS unit tests pass, including concurrent preference writes, fresh reads,
  per-language learning, pause/reset, corrupt-file preservation and no draft storage.
- Development signing succeeds for app and extension with the App Group entitlement.
- Device installation and app/extension preference round-trip still need a connected
  phone. Change language/target in one, reopen the other; test learning and reset.
- Verify actual Foundation Models refinement/translation on the phone, offline,
  cancellation and repeated sharing. Simulator mocks do not validate model quality.
- Review machine translations, RTL layout, Dynamic Type and VoiceOver on device.
- Create/confirm the App Store Connect record for `app.inigo.mobile`, produce an
  Apple Distribution archive, validate and upload. This branch has not uploaded a
  TestFlight build and does not automate mobile distribution.
- Complete beta description/contact information, privacy and export-compliance
  answers in App Store Connect. External testers need Apple's beta review; internal
  testers must be eligible App Store Connect users.

TestFlight can start with a clearly scoped iPhone beta; desktop global shortcuts,
Accessibility replacement, custom local model servers and Sparkle are not iOS
features. Sharing returns a copyable result and never replaces another app's draft.

## Build 5 follow-up

Owner reported trailing output-wrapper punctuation after refinement and no visible
translation action for Ukrainian. Refinement now uses a typed Foundation Models
response. Translation uses a flat language picker, starts without waiting on a
modal dismissal callback, and presents failures in a dialog. A controller regression
selects Ukrainian and confirms the draft and target reach the translation handler.
45 iOS tests pass; actual device output quality and Ukrainian model availability
still require verification. Settings now keeps learned counters and reset on a
secondary page, with shorter copy in all 24 interface languages.

## Build 6: dedicated offline translation

Translation no longer depends on Apple Intelligence's writing-model language list.
The phone capability probe confirms 18 offered languages, including Ukrainian and
Polish. Interface localization remains available in 24 languages. The six translation
gaps and candidate/licensing evaluation are recorded in
[the translation evaluation](Benchmarks/translation-evaluation.md).

Missing packs prompt for Apple's download authorization; downloaded packs are
shared by the system and work offline. The action and settings pickers query native
translation support rather than promising every interface language. The first phone
probe found no installed English/Polish/Ukrainian pairs: capability alone is not a
translation benchmark. Further device timing/quality tests are pending downloads
and an unlocked phone. The normal simulator suite has 47 passing safety/UI tests.

For physical synthetic benchmarks, run the `InigoTranslationDevice` scheme. It
attaches JSON and measures installed pairs only; it never reads personal text.
This scheme is separate from the normal simulator suite and Mac release workflow.
