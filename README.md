<p align="center"><img src="Assets/Inigo.png" width="128" alt="Inigo icon"></p>

# Inigo

**A small shortcut. A clearer message.**

Inigo is a native macOS menu-bar app for refining and translating writing in the
app you already use. Local models keep your writing on your Mac.

**Status: experimental pre-release.** Source is available for review and contributions.
There is no endorsed public installer yet. See [release gates](docs/releasing.md).

## What it does
- **⌥I** refines a selection or current paragraph; **⌥⇧I** translates.
  Both shortcuts are editable.
- Offers 24 translation targets and interface languages.
  The interface follows macOS or your override, with RTL layouts.
- Replaces text only when the editor can be checked safely. Read-only selections
  and unsupported editors get a small copyable result.
- Protects mentions and link destinations; guarded Undo avoids overwriting later edits.
- Runs Qwen 3.5 locally, or connects a compatible GGUF file/local server.
- Never sends your message, captures screenshots or collects conversation history.

## Model choice
Our [multilingual benchmark](benchmarks/report.md) on an M5 with 24 GB found 9B most
faithful on the tested language sample at about four seconds per short request. 4B had a median of roughly two seconds;
2B roughly one, with more quality errors. These are median timings, not guarantees.
Existing model selections do not switch automatically. Review wording before sending.

## Compatibility
Apple Silicon, macOS 15+, full Xcode for building. Measured hardware: M5/24 GB.
Accessibility access is required for most in-place editing. Browser use requires
explicit selected text. Rich mentions, tables, smart chips and suggestion-mode
editing can fall back to Copy. Google Docs and Slack rich-content replacement are
not broadly certified. [Compatibility matrix](docs/compatibility.md).

## Build

For Xcode, open **Inigo.xcodeproj**, select the **Inigo** scheme and **My Mac**.
Choose your team under Signing & Capabilities. See [Xcode setup](Xcode/README.md).

```sh
git clone https://github.com/vladkampov/Inigo.git
cd Inigo
bash scripts/bootstrap.sh
bash scripts/test.sh
bash scripts/build.sh
open dist/Inigo.app
```
Use full Xcode and Node 22+ for optional bridge tests. No model is needed for unit
tests. Model weights are downloaded separately. The standard build is ad-hoc
signed for development, **not a public installer**. See [direct distribution,
signing and updates](docs/releasing.md) for a notarized release.

## Privacy and updates
No usage analytics. Optional handled-error reports are off by default and contain
only fixed error categories and version information; no endpoint is configured yet.
Signed updates use Sparkle, with hourly checks while running and manual installation.
Update hosting receives connection metadata but no writing.
[Privacy policy](PRIVACY.md) · [Security reporting](SECURITY.md).

## Help build it
[Contributing](CONTRIBUTING.md) · [Code of conduct](CODE_OF_CONDUCT.md) ·
[Report a bug](https://github.com/vladkampov/Inigo/issues/new?template=bug_report.yml) ·
[Request a feature](https://github.com/vladkampov/Inigo/issues/new?template=feature_request.yml) ·
[Share feedback](https://github.com/vladkampov/Inigo/issues/new?template=feedback.yml).

MIT licensed. Dependencies and separately downloaded models retain their own
licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).
