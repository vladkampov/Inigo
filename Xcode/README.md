# Inigo in Xcode

Open Inigo.xcodeproj and select the **Inigo** scheme / **My Mac**.

## Choose your account
Select the blue Inigo project in the navigator → Inigo app target →
Signing & Capabilities → Team. Choose your paid Apple Developer team.
The project deliberately does not guess a Team ID from a certificate name.

Debug and Archive use automatic Apple Development signing. To obtain the
certificate for direct distribution, open Xcode → Settings → Accounts →
your team → Manage Certificates → + → Developer ID Application.
Creating this certificate requires the team's Account Holder.

After creating it, return to the release workflow in docs/releasing.md.
A Developer ID certificate is selected during Organizer's Developer ID export,
or by scripts/release.sh. Do not confuse Apple Development with Developer ID.
Do not publish a development-signed archive.

## Build
Sources are shared with Package.swift; this is a real app target, not an external
build wrapper. Sparkle is an exact-version package dependency. The build copies
the local llama runtime and all interface translations into the bundle.
Run scripts/bootstrap.sh once if the runtime is missing.

Model weights are never embedded. Run starts Settings using --settings.
Xcode does not overwrite the personal app in dist/.

## Maintain
project.yml is the XcodeGen source. After version changes or adding files, run
bash scripts/generate-xcode-project.sh (requires XcodeGen).
Keep signing-account selections local; do not commit personal provisioning data.
Public update configuration and notarization remain in scripts/release.sh.
