# Privacy

Inigo reads text only when invoked. It never uses screenshots, OCR or background
clipboard monitoring. Built-in and imported GGUF models process writing on your Mac.
A separately managed local server can forward data elsewhere; its policy is yours
to verify. Inigo only connects to loopback addresses for that integration.

Drafts, context and Undo snapshots stay in memory and expire. A compact style
profile stores only predefined writing preferences. No conversation history or
cross-device synchronization is kept. Compatibility paste briefly uses the
clipboard and restores it only if ownership remains unchanged; clipboard managers
may retain that temporary content.

Browser processing requires an explicit selection, including in private windows.
Surrounding browser conversation text is not sent to a model. Editor values may
be read locally to validate replacement. Secure fields and excluded apps are skipped.

## Network activity
Model downloads contact Hugging Face and its file hosts. Signed app-update checks
contact the configured GitHub Pages feed approximately hourly while Inigo runs,
unless disabled. Update downloads contact GitHub Releases. These services receive
ordinary connection metadata such as IP address. Writing is never included.
Sparkle system profiling and automatic installation are disabled.

## Optional error reports
Off by default. When configured and enabled, handled errors send only a fixed
error category, app release and OS major version. No draft, context, clipboard,
URL, custom model identifier, file path, raw exception, user identifier, session
tracking or usage analytics is sent. This is not a full crash-dump collector.
The reporting provider receives IP/network metadata. The owner must document the
provider/project and retention policy before enabling it in distributed builds.
No reporting endpoint is configured in the source defaults.

Turning reports off cancels pending uploads. There is no persistent report queue.
