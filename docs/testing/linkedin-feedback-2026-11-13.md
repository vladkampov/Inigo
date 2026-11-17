# LinkedIn feedback implementation checks — 2026-11-13

Source changes add compatibility guidance, processing stages and content-free
operation details, structured feedback, and opt-in automatic layout repair.
Automatic repair remains off by default. This record does not certify live editors.

## Passed

- Swift: 69 tests, 67 passed and two existing model/server integration tests
  skipped because no test endpoint was configured. The opt-in macOS layout tests
  were enabled. Core and application targets compiled successfully.
- macOS integration: discovered the enabled U.S./Ukrainian layouts and their
  actual key maps; spelling-service checks recovered four synthetic examples in
  both directions and rejected nine valid/ambiguous/protected negative examples.
  These checks did not type text, switch sources, create an event tap or grant
  permissions. Apple Ukrainian maps `ghsdbn` to `привіт`; PC-layout fixtures differ.
- Named-pasteboard transaction tests passed with macOS service access. An initial
  restricted-sandbox run failed those existing tests because pasteboard services
  were inaccessible; rerunning with service access passed without changing tests
  or the user's general clipboard.
- Seven Node OAuth/bridge tests and 22 Python release/tooling tests passed.
- All 24 interface catalogs are complete and preserve placeholders. New strings
  were translated with the bundled local model; human language review is pending.
- Publication hygiene, whitespace checks, and plist/project syntax validation passed.

## Remaining live release gates

Use [automatic-layout-repair.md](automatic-layout-repair.md) on the actual signed
candidate and a second supported Mac. Keyboard listening/consent/revocation,
typing/focus races during writes, direct AX value replacement, caret/Undo behavior,
source switching, rich objects and exact browser/private-window/editor support
still need live validation. Do not label those paths certified from unit tests.

Current first/warm end-to-end latency distributions and an uncut demo are pending
signed-candidate runs. The app now provides stage timings to collect this evidence;
the historical raw model comparison is explicitly labeled as such.
