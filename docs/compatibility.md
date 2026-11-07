# Compatibility and validation

Recorded 2026-11-06: Apple M5, 24 GiB unified memory, macOS 26.6.2.
Deployment baseline is macOS 15 on Apple Silicon; other OS/hardware combinations
remain unverified. Public release requires a clean-Mac test matrix.

| Area | Evidence / limitation |
|---|---|
| Native settings/onboarding | Visually inspected; keyboard shortcuts configurable |
| Local models | Pinned 2B/4B/9B loaded and benchmarked; see benchmarks/report.md |
| Multilingual quality | 126 historical outputs from a retired corpus; text payloads removed. Replacement fictional fixtures need a new measured run |
| Translation Services | A tested cross-language selection produced the requested target-language popup |
| Protected tokens | Missing/reordered mention/link markers rejected by tests |
| Clipboard transaction | Isolated tests preserve all items and avoid overwriting new copies |
| Readback | Delayed writes, cancellation, CR/LF and Unicode equivalence tested |
| TextEdit | Selection and Services exercised; in-place trust depends on signing |
| Codex/ChatGPT | User confirmed picker translation/replacement works; earlier intermittent copy-only result remains unresolved (#21) |
| Slack | Rich-content preservation not live-certified; protected rich content falls back |
| Browser AX | Explicit selection only, including private windows; no surrounding context |
| Google Docs | Structured rich editing not implemented; use copyable fallback |
| Browser selections via macOS | Explicit selection only; editor-specific replacement must be verified; copyable fallback available |
| RTL/interface locales | 24 machine-translated catalogs; human review required |
| Updates | Real beta.6 (1018) → beta.7 (1020) Sparkle install/relaunch passed; preferences retained; stable channel still pending |
| Error reporting | Content-free opt-in integration; no live endpoint configured |

No universal “works in every editor” claim. Ad-hoc development builds can lose
Accessibility grants after rebuild. Developer ID signing and notarization passed in CI through 0.2.0-beta.7.
Clean-Mac onboarding/offline and editor matrices remain incomplete. A second Mac
was reported to launch successfully; work-Mac Chrome/Slack focus failures remain
unreproduced and are not established to be device-management restrictions.
