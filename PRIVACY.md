# Privacy

Manual refinement and translation read text when invoked. Optional automatic
keyboard-layout repair is off by default. Enabling it explicitly permits reading
the whole focused draft after typing pauses in native and browser inputs, including
private windows. A passive keyboard listener uses event timing and key metadata;
Inigo does not extract or save keystroke text. Automatic repair uses macOS keyboard
maps and spelling services, without calling a model or inference server. Secure
input, excluded apps and unverifiable fields are skipped. Disable the feature to
stop listening, cancel pending repair, and clear its transient result state.

Inigo never uses screenshots, OCR or background clipboard monitoring.
Built-in and imported GGUF models process writing on your Mac.
A separately managed local server can forward data elsewhere; its policy is yours
to verify. Inigo only connects to loopback addresses for that integration.

Drafts, context and Undo snapshots stay in memory and expire. A compact style
profile stores only predefined writing preferences. No conversation history or
cross-device synchronization is kept. Compatibility paste briefly uses the
clipboard and restores it only if ownership remains unchanged; clipboard managers
may retain that temporary content.

Manual browser processing requires an explicit selection, including in private windows.
Surrounding browser conversation text is not sent to a model. Editor values may
be read locally to validate replacement. Secure fields and excluded apps are skipped.

Content-free last-operation details (version, macOS version, memory/processor count,
fixed model category, outcome and stage durations) stay in memory. They are not
uploaded automatically. Copying them is an explicit clipboard action; sharing them
in a report is your choice. They contain no writing, target app identifier,
custom model name, path, endpoint or raw exception.

## Network activity
Model downloads contact Hugging Face and its file hosts. Signed app-update checks
contact the configured feed on raw.githubusercontent.com approximately hourly while Inigo runs,
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
