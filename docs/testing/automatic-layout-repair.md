# Automatic layout repair beta test card

Use a signed candidate containing the source changes; beta.7 does not contain
this feature. Only synthetic disposable drafts. Record Inigo build, app versions,
macOS, chip/RAM and enabled layouts. Do not change managed-device policy.

1. On fresh preferences and after upgrading, confirm automatic repair is off.
   Manual refine/translation still require explicit browser selection. No keyboard
   listening prompt appears until the feature is enabled.
2. In Keyboard Layout settings, enable repair and review the background-access
   disclosure. Grant requested access through normal system controls. Confirm
   enabled layouts match macOS; add/remove/change a layout and check the list.
3. With U.S. selected, type `ghsdbn` in a plain TextEdit input. Pause at least
   800 ms. Expect `привіт`, Ukrainian selected, the caret retained, and a
   nonactivating notification. Repeat in reverse with a six-letter English word.
4. Type a whole wrong-layout phrase with spaces, case and punctuation. Existing
   draft text is part of this mode: confirm the whole field converts, not just
   the last word. URLs, mentions, email addresses and emoji must remain exact.
5. Undo immediately. The exact original and caret should return; the input source
   returns only if it still matches Inigo's choice. Continue typing or manually
   change the layout before Undo: later edits/layout choices must survive. The
   undone draft must not immediately correct itself again.
6. During the pause/detection/write, type more, click elsewhere, move the caret,
   switch apps/layouts, open the translation picker, or invoke manual refine.
   No stale correction may apply. Repeat rapidly. Record NOT EXERCISED if timing
   makes interruption impossible; unchanged text alone is not a compatibility pass.
7. Valid prose, names, code, short fragments, mixed-language drafts, ambiguous
   three-layout cases, unsupported input methods and drafts over 20,000 UTF-16
   units should remain unchanged when confidence/mapping requirements fail.
8. Repeat in native and browser inputs: Codex, Slack, Chrome/Gmail, Safari inputs,
   private windows, and Google Docs. Record AUTO REPLACEMENT / MANUAL ONLY /
   COPY ONLY / UNSUPPORTED for each exact app/editor version. Automatic mode
   requires direct AX value writes and verified plain text; never loosen those
   checks to make an editor pass. Check rich objects remain functional or untouched.
9. Test a password field and excluded app. No text should be captured or changed.
   Pause/disable repair and revoke listening/Accessibility access separately.
   Pending correction must stop; manual workflows remain available where permitted.
10. Test offline, with the model stopped: layout repair must need no model/server.
    Verify a listening timeout pauses rather than spinning; resume explicitly.
11. Run the same card on a second supported Mac. Record PASS/FAIL/NOT TESTED for
    each scenario. Stop at any unexpected text change or loss.

The opt-in developer check `INIGO_TEST_LAYOUTS=1 swift test --disable-sandbox
--filter LayoutDetectionTests/testSystemLayoutsWhenExplicitlyEnabled` verifies
U.S./Ukrainian mapping and OS spelling evidence without writing text or switching
input sources. Run it in a context with access to macOS spelling services; restricted
automation sandboxes may deny the service. It does not certify live editors.

For speed, use current fictional fixtures and record first-use and warm runs of
short and longer drafts. Support → Last operation details includes capture, load,
generation, validation, insertion and total timings, including retries. Collect at
least 20 samples per measured condition for median/p95. State hardware/model/build;
do not substitute raw inference timings for end-to-end measurements. Record an
uncut demo only after signed-candidate validation, with configuration visible.
