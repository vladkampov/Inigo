# Interface catalogs

24 locales. `en.json` is the source-key catalog. Other catalogs were translated on-device with the bundled candidate Qwen model; native-speaker review is still needed before public distribution.

Run `python3 scripts/translate-catalogs.py` to fill missing keys (uses the workspace model/runtime, four local inference slots; no provider calls). Existing translations are preserved so human edits survive regeneration. Review proper nouns, placeholders, tone, and narrow-window/RTL layout.

`package-localizations.py` rejects incomplete catalogs and writes the combined runtime resource plus localized Services names. UI language is resolved from an explicit override or macOS preferred-language order, with English fallback. The preference never changes the language of the draft or the translation target.

Critical privacy, compatibility and recovery/error messages are pinned in
`scripts/fixtures/critical-localizations.json` after review found inverted actions
and missing failure negations. `scripts/check-localizations.py` checks their exact
curated copy as well as catalog completeness and placeholders. Review intentional
changes to those fixtures together with the corresponding catalogs. These checks
prevent known regressions; they do not establish fluent-speaker review or prove
the semantics of other translations.
