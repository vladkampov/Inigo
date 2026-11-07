# Second-Mac test card

Use only synthetic text. Allow about 20–30 minutes, plus the model download.
Record Mac chip/RAM, macOS version, Inigo version/build and each editor version.
Do not send a serial number, personal writing, or work screenshots.

The latest public test baseline is beta.7. Source fixes merged after beta.7 are
not in that binary; repeat this card on the final signed release candidate.
Download from https://github.com/vladkampov/Inigo/releases/tag/v0.2.0-beta.7 .

## Installation and preparation

1. Download the ZIP directly in the second Mac's browser, unzip, move Inigo.app
   to Applications and open it. Expected: ordinary verified-app opening, no
   “damaged” or “cannot be opened” error. Do not remove quarantine or bypass
   Gatekeeper. Record the exact message if blocked.
2. On a Mac/account that has never used Inigo, expect onboarding. If it has been
   used before, use Open guided setup; do not delete preferences. Mark this as
   repeat setup, not a clean-install pass.
3. Enable Inigo under macOS Privacy & Security → Accessibility. Return to setup,
   download the recommended model and complete its sample rewrite. Record
   chosen model, download errors, and approximate first/warm rewrite times.
4. Quit/reopen Inigo. Confirm shortcut and model choices persist.

## Core editor checks

Start in TextEdit, Format → Make Plain Text, with this exact draft:

> Hello team. I think we can finish by Friday, but we still needs confirmation. Could you shares an update? 🙂

5. Select the draft and physically press Option–I (or your configured shortcut).
   Expected: grammar improved; Friday remains tentative; no text is sent;
   emoji and meaning retained. Record replacement vs copy-only and HUD text.
6. Immediately click Inigo's Undo during the 3-second success message. Expected:
   the exact original comes back. This is Inigo Undo, not TextEdit's Cmd–Z.
7. Refine again; after success type ` EXTRA`. If Inigo Undo is still available,
   click it. Expected: it must not erase this subsequent edit.
8. Start a rewrite, then immediately type or switch to a different field.
   Expected: cancellation/no stale replacement. Repeat quickly twice and check
   that neither result overwrites your later input. If too fast to interrupt,
   record “not exercised”, not pass.
9. Set translation target to Polish. Select `Ми, можливо, завершимо до п’ятниці,
   але дату ще потрібно підтвердити.` Use the direct translation shortcut,
   then restore and repeat through Services → Translate with Inigo and its picker.
   Expected: Polish output, uncertainty preserved; input replaced or an explicit
   copy-only result. Settings must not unexpectedly open.
10. Repeat steps 5, 6 and 9 in a disposable Slack desktop draft and Gmail/Chrome
    draft, if available. Never send. Record each app separately. Also test a Slack
    mention and a linked phrase: they must stay functional or Inigo must leave the
    original unchanged and provide copy-only output. Plain text that merely looks
    like a mention does not prove a functional mention survives.
11. Select a short paragraph outside an input (e.g. on a public webpage), translate,
    and confirm a copyable popup appears without altering the webpage.

## Offline and failure checks

12. After the model is ready, on a personal/unmanaged Mac temporarily turn Wi-Fi
    off using normal controls. Refine the sample again. Expected: local rewriting
    still works. Restore Wi-Fi. Skip this if it would disrupt work/network policy.
13. With a harmless draft, quit Inigo and reopen it; verify rewriting still works
    without downloading again. Report repeated model loading failures or hangs.
14. Check for Updates. Record the result; do not expect an update if already on
    the newest release. Do not treat this as a beta-to-stable migration test.

## Report back

For each numbered step: PASS / FAIL / NOT TESTED, exact error text, whether the
original changed, whether replacement or copy-only occurred, and approximate
latency. Stop if any original text disappears unexpectedly. A managed work Mac
may have restrictions; do not change management/security policy to make it pass.
