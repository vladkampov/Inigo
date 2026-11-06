# Compatibility and validation

Recorded 2026-11-06: Apple M5, 24 GiB unified memory, macOS 26.6.2.
Deployment baseline is macOS 15 on Apple Silicon; other OS/hardware combinations
remain unverified. Public release requires a clean-Mac test matrix.

| Area | Evidence / limitation |
|---|---|
| Native settings/onboarding | Visually inspected; keyboard shortcuts configurable |
| Local models | Pinned 2B/4B/9B loaded and benchmarked; see benchmarks/report.md |
| Multilingual quality | 126 synthetic outputs across a limited language sample; see benchmark scope and known errors |
| Translation Services | A tested cross-language selection produced the requested target-language popup |
| Protected tokens | Missing/reordered mention/link markers rejected by tests |
| Clipboard transaction | Isolated tests preserve all items and avoid overwriting new copies |
| Readback | Delayed writes, cancellation, CR/LF and Unicode equivalence tested |
| TextEdit | Selection and Services exercised; in-place trust depends on signing |
| Codex/ChatGPT | User reported successful paste with occasional false warning; fixes need user retry |
| Slack | Rich-content preservation not live-certified; protected rich content falls back |
| Browser AX | Explicit selection only, including private windows; no surrounding context |
| Google Docs | Structured rich editing not implemented; use copyable fallback |
| Optional Chrome extension | Source/privacy tests present; manual compatibility gate remains |
| Optional Safari wrapper | Not shipped/activated; signing and integration remain |
| RTL/interface locales | 24 machine-translated catalogs; human review required |
| Updates | Sparkle integrated; signed N→N+1 installation test pending published feed |
| Error reporting | Content-free opt-in integration; no live endpoint configured |

No universal “works in every editor” claim. Ad-hoc development builds can lose
Accessibility grants after rebuild. Developer ID signing and notarization passed for 0.2.0-beta.1; clean-Mac testing remains.
