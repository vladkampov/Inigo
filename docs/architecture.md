# Inigo architecture

Inigo is a native SwiftUI/AppKit menu-bar utility. InigoCore holds text-range safety, protected-token validation, prompts, and the closed-vocabulary style profile. The app coordinates Accessibility capture, generation, output validation, replacement and temporary undo state. Requests have generation identifiers so cancelled work cannot update a newer operation.

## Processing

Local: bundled llama.cpp b12172, listening only on loopback with a random per-process bearer token. Qwen3.5-4B Q4_K_M (2,740,937,888 bytes), Apache-2.0 model license. SHA-256: `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4`. Model download is verified before installation. No text leaves the machine in Local mode. The model server's stdout/stderr are discarded and its logging is disabled.

Cloud: Inigo implements the public Sign in with ChatGPT OAuth specification in `CloudBridge/oauth.mjs`, using Node's HTTP/crypto APIs, the MIT-licensed `jose` JWT library, and the Apache-2.0 OpenAI API library. The noncommercial DevKit was evaluated and removed because its license does not fit employer-related writing. No DevKit code is included in the app. The implementation validates state, PKCE, issuer, audience, nonce, expiration and account identity; serializes refresh; checkpoints token rotation; revokes on sign-out; and waits for completed Responses streams. Tokens live in macOS Keychain and travel only over the private helper pipe. Disk stores an opaque Keychain reference and installation/registration identifiers.

Cloud verification requires the user to finish browser sign-in. No existing ChatGPT or Codex credential is read or reused. OpenAI plan usage and retention are subject to provider policies.

## Editor safety

Accessibility reads only a focused non-secure text role. A selected range wins; otherwise Slack's message draft or the current paragraph is used. Context currently includes only an exposed visible range in the active field. Surrounding Slack thread messages are NOT yet captured: distinguishing visible message text from sidebars and hidden history requires an app-specific adapter.

In-place writes require a settable selected-text attribute and uniform attributed text with no links, attachments, lists or headings. Unknown formatting is copy-only. Rich mention identity cannot be inferred from plain strings. The adapter therefore does not claim rich Slack mention round-trips are verified. It rechecks focus, text, selection and formatting before writing. Undo similarly requires the replacement to remain unchanged.

Manual browser and unrecognized editor access requires explicitly selected text and supplies no surrounding context, including in private windows. The experimental Chrome and Safari extensions and their native bridge have been removed. Unsupported editors offer a copyable result; arbitrary Google Docs canvas editing is not guaranteed.

## Automatic keyboard-layout repair

This optional mode starts disabled. Enabling it includes explicit consent for whole
focused-input access in native apps and browsers, including private windows.
InputSourceCatalog discovers enabled/selectable macOS layouts and observes source
changes. A passive session event tap retains timing/key metadata only; after an
800 ms pause the controller captures the entire verifiable plain input, up to
20,000 UTF-16 units, without surrounding context. Secure input and excluded apps
are skipped before reading values.

Conversion uses reversible Unicode key maps, preserving protected objects. macOS
spelling evidence must recognize at least 90% of candidate letters and at most 20%
of original letters, with six letters minimum and a 25-point lead over alternatives.
Missing dictionaries, unavailable evidence and ambiguous maps produce no repair.
A same-alphabet synthetic nonword checks spelling-service health before accepting
recognition scores. Individual checks time out after two seconds and a detection
pass has a ten-second budget.
No inference server is called. Recognition is asynchronous and bounded; generation
tokens cancel obsolete decisions after typing, focus, selection or source changes.

Automatic replacement requires a directly settable Accessibility value. It never
selects an entire draft or uses the clipboard to perform automatic repair; editors
requiring Paste remain manual-only. Readback, caret restoration, guarded Undo,
source-switch checks and field suspension after ambiguous writes apply. Manual
operations and pickers take precedence. Undo suppresses immediate recorrection;
input-source restoration never overrides a later manual source choice.

Operation stage timings use a monotonic clock and fixed model/outcome categories.
Support details stay in memory and are copied only by user action. They are separate
from optional error uploads and contain no writing, raw error, app ID or custom path.

## Privacy and retention

No screen capture, OCR, background clipboard monitoring, telemetry or conversation-history files. Temporary fallback and undo data expire after two minutes. Credentials never appear in application logs. Only enum-based style preferences and evidence counts are saved, separated by language. Retained results count as weak evidence; three consistent observations are needed to activate a preference. Automatic learning from later corrections and browser edits is not yet enabled.

## Source references

- https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt
- https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- https://github.com/openai/sign-in-with-chatgpt-devkit
- https://github.com/ggml-org/llama.cpp/releases/tag/b12172
- https://huggingface.co/unsloth/Qwen3.5-4B-GGUF

Services registration follows Apple's Services Properties documentation: an empty NSRequiredContext enables menu discovery; ServicesMenu.strings localizes service names. The provider accepts selected plain text and returns immediately, with results delivered asynchronously in Inigo. No source pasteboard return type is declared; safe editable replacements go through the normal editor validation path.
Reference: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html

The personal release now keeps separate preferences for interface locale (system by default), default translation target and translation hotkey. The shared 24-language enum controls model instructions and settings options; translation targets are not derived from interface language. One-off picker choices leave the default unchanged. Read-only results offer a copyable translation; no service sends messages. Support links point to GitHub and buymeacoffee.com/kampov. Model selection is documented in local-model-management.md.
