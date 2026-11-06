# Contributing to Inigo

Small, focused contributions are welcome: editor compatibility, language review,
accessibility, tests and documentation. Start with an issue before a large change.

## Develop
Use an Apple Silicon Mac, macOS 15+, full Xcode and Node 22+ for the optional bridge
tests. Run `scripts/bootstrap.sh`, `scripts/test.sh`, then `scripts/build.sh`.
No model or Apple Developer account is required for ordinary unit tests.
A local model is required for integration benchmarks. See benchmarks/README.md.

## Pull requests
Explain the user-visible problem, include the relevant tests and screenshots for
UI changes, and describe any privacy effect. Keep commits focused. Do not include
real writing, conversation context, credentials, machine-specific paths, model
weights, build products or generated runtime binaries.

Preserve protected structures and uncertainty. Never treat a successful paste
command as proof of replacement. Do not add background text capture, remote
inference fallback, or telemetry containing text. Test cancellation and Undo.

Translations are in Localization/*.json. Preserve placeholders. Machine-generated
translations need human review. Run scripts/check-localizations.py after editing.

Contributions are accepted under the MIT license. You must have the right to
submit them. No CLA is required. Maintainers review and merge; please allow time.

## Finding a first issue
The `good first issue` label is for scoped tasks with clear acceptance criteria,
not automatically every bug. Suggested starter tasks are in docs/starter-issues.md.
