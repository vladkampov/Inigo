# Interface catalogs

24 locales. `en.json` is the source-key catalog. Other catalogs were translated on-device with the bundled candidate Qwen model; native-speaker review is still needed before public distribution.

Run `python3 scripts/translate-catalogs.py` to fill missing keys (uses the workspace model/runtime, four local inference slots; no provider calls). Existing translations are preserved so human edits survive regeneration. Review proper nouns, placeholders, tone, and narrow-window/RTL layout.

`package-localizations.py` rejects incomplete catalogs and writes the combined runtime resource plus localized Services names. UI language is resolved from an explicit override or macOS preferred-language order, with English fallback. The preference never changes the language of the draft or the translation target.
