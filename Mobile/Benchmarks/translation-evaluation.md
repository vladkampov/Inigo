# iPhone translation evaluation — 2026-11-07

## Decision

Use Apple's dedicated Translation framework with the **lowLatency** strategy,
not the Foundation Models writing model. This is a provisional engineering choice
based on actual device capability and deployment fit, not a claim that it beat
all competing models in a quality benchmark.

The physical iPhone 17 Pro Max reports 18 of our 24 interface languages supported:
English, Spanish, French, German, Portuguese, Italian, Dutch, Polish, Ukrainian,
Turkish, Arabic, Hindi, Indonesian, Vietnamese, Thai, Chinese, Japanese and Korean.
Persian, Urdu, Bengali, Tamil, Telugu and Marathi are **not** supported by this
engine on the tested phone. Keep their UI localizations, but do not advertise them
as translation targets. The picker queries runtime availability, excludes Russian
as elsewhere in Inigo, and does not rely on a hardcoded OS-language list.

## Candidates screened

| Candidate | Evidence | Decision |
|---|---|---|
| Apple Translation, lowLatency | Device API reports Polish and Ukrainian; shared downloaded packs, native download authorization; traditional models distinct from Apple Intelligence | Implement and measure on device |
| Apple Foundation Models | Previous phone translation attempts failed; model-language constraints differ from Translation | Retain for refinement only |
| TranslateGemma 4B | Google reports translation evaluation across 55 languages; gated model access and a separate mobile inference/runtime integration are needed | Not phone-benchmarked; possible future standalone-app candidate, not assumed safe for Share extension memory |
| HY-MT1.5 1.8B | Model card covers all 24 languages; license explicitly excludes the EU, UK and South Korea | Exclude from this Poland-based release; no weights downloaded |
| NLLB-200 distilled 600M | Broad coverage; CC-BY-NC license, research-oriented model | Exclude as default for an unrestricted public app; no weights downloaded |
| Qwen3.5 0.8B | Apache-2.0, broad multilingual claims; general model rather than a dedicated translation engine | Not phone-benchmarked; requires runtime, download integrity, memory and quality validation before shipping |

No license acceptance, account creation, cloud inference or external writing
upload was performed. A broad language claim is not a quality score.

## Reproduction and evidence

`InigoTranslationDevice` is a separate, app-hosted XCTest scheme. It runs synthetic
fixtures on the phone and attaches JSON results. It does not read clipboard or
user drafts. Normal simulator tests do not trigger model downloads.

Initial physical probe: all six directions between English, Polish and Ukrainian
reported `supported`, not `installed`. This proves capability but **not inference**.
See `Results/native-translation-initial.json`. User-authorized language downloads
and subsequent measured runs are required. Record cold/first and warm timings,
actual output, meaning/tentativeness, numbers/dates, links/mentions and failures.
The synthetic cases are short; they cannot establish universal translation quality.

## Implementation requirements

- Pin lowLatency on iOS 26.4+ rather than inheriting a changing strategy default.
- Request missing language packs through Apple's translationTask UI; after download,
  use installedSource sessions. No automatic cloud fallback.
- Preserve the original on unsupported source/pair, cancellation, timeout, language
  validation failure or protected-token damage. Download waiting is cancellable.
- Settings and the action picker use engine-supported targets; interface language
  options remain independent. Same-language text is returned unchanged.
- All 24 translation languages remain an unmet goal. Adding a second engine needs
  real-phone memory/lifecycle tests, redistribution review and language-quality tests.

## Primary sources

- [Apple language availability](https://developer.apple.com/documentation/translation/languageavailability)
- [Installed-language sessions](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:))
- [Low-latency strategy](https://developer.apple.com/documentation/translation/translationsession/strategy/lowlatency)
- [Apple feature availability](https://www.apple.com/ios/feature-availability/)
- [Google TranslateGemma](https://blog.google/innovation-and-ai/technology/developers-tools/translategemma/)
- [HY-MT model](https://huggingface.co/tencent/HY-MT1.5-1.8B) and [license](https://huggingface.co/tencent/HY-MT1.5-1.8B/blob/main/License.txt)
- [NLLB model and license](https://huggingface.co/facebook/nllb-200-distilled-600M)
- [Qwen model card](https://huggingface.co/Qwen/Qwen3.5-0.8B)
