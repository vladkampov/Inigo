# CI/CD setup

## What runs

- Pull requests and main merges: CI tests, catalog validation and repository hygiene.
- Main merges: Release Please opens/updates a version + changelog PR. It uses the
  built-in GitHub token, no personal access token. Bot PR checks are explicitly
  dispatched because bot-created PR events do not trigger other workflows.
- Merge a release PR: a draft prerelease is created. When enabled, the same workflow
  signs on macOS, notarizes, staples, verifies the final extracted ZIP and Sparkle
  signature, then attaches ZIP, checksum and appcast to the draft.
- No auto-merge and no automatic public publishing. Publishing and feed deployment
  stay deliberate until the separate public-distribution review.
- Failed signing can be retried with Release → Run workflow, branch main, exact
  existing draft tag. Existing assets are never overwritten.

## Versioning

Use Conventional Commit squash titles: `fix: ...`, `feat: ...`, or
`feat!: ...` for an incompatible change. During beta, the prerelease versioning
strategy produces beta versions automatically. The current baseline is
0.2.0-beta.1. VERSION and CHANGELOG are reviewed in the generated release PR.
Before 1.0, incompatible changes bump minor rather than jumping to 1.0; features
also bump minor and fixes patch once stable versioning is enabled.

To graduate to stable, change versioning to `default`, prerelease to false,
remove prerelease-type, and explicitly review the first stable release version.
CI sets a monotonic CFBundleVersion to 1000 + the Release workflow run number;
it does not reuse the local beta build 2. Keep that workflow identity and offset
stable. Reruns retain their build number and cannot replace uploaded assets.

## Protection prerequisite

The repository is currently private on a plan that rejects branch rules (HTTP
403). The owner chose a separate publication review before making it public.
Do not change visibility as part of this setup. After review/publication:

1. Apply `.github/rulesets/main.json` via GitHub Rulesets import or API. It requires
   PRs, passing/up-to-date `tests`, resolved conversations, squash/linear history,
   and blocks deletion/force pushes. No bypass list. Zero required approvals is
   intentional for a solo maintainer who cannot approve their own PR; change to
   one when another maintainer is available.
2. Create an environment named `release`; restrict deployment branches to exactly
   `main` (selected branches, not arbitrary tags). Add a required reviewer if
   desired; this adds a human gate before each signing job.
3. Keep repository default token permissions read-only. GitHub's combined
   "create and approve pull requests" switch is enabled with owner approval so
   Release Please can create PRs. This workflow never approves PRs.

## Secrets needed (environment: release)

| Name | Source |
|---|---|
| DEVELOPER_ID_P12_BASE64 | Base64 of password-protected Developer ID Application certificate AND private key export |
| DEVELOPER_ID_P12_PASSWORD | Password chosen for that export |
| APPLE_API_PRIVATE_KEY | Original App Store Connect Team API key `.p8` file contents |
| APPLE_API_KEY_ID | Key ID from App Store Connect |
| APPLE_API_ISSUER_ID | Issuer ID from App Store Connect |
| SPARKLE_PRIVATE_KEY | Existing `app.inigo.updates` key exported by official Sparkle tool |

Do not generate a new Sparkle key: installed apps trust the existing public key.
Do not use Apple Development certificates. The expected Developer ID team is
JKAL24VVB9. Public key and signing identity are public configuration, not secrets.

In Keychain Access → login → My Certificates, select **Developer ID Application:
Vladyslav Kampov (JKAL24VVB9)** with its private key, choose Export, Personal
Information Exchange (.p12), and protect it with a strong password. Keep the
file outside the repository. macOS may ask for your login password.

After the environment is protected, run locally (replace example paths/IDs):

```sh
python3 scripts/configure-release-secrets.py \
  --p12 /absolute/path/Inigo-Developer-ID.p12 \
  --api-key /absolute/path/AuthKey_KEYID.p8 \
  --key-id KEYID --issuer-id ISSUER_UUID
```

The helper prompts for the export password without echo, exports only the existing
Sparkle key into a temporary directory, and pipes secrets to `gh secret set`.
It never prints private values or stores them in the repository. Allow the official
Sparkle tool's Keychain prompt locally if shown. The temporary export is removed.
Keep your original key files in secure backup storage.

Finally set the repository Actions variable `RELEASE_SIGNING_ENABLED=true`.
Until then signing jobs are skipped. Do not enable before environment restrictions
and secrets are complete. No secrets are exposed to pull-request jobs. Runner
credentials are imported into a temporary keychain and removed in an always-run
cleanup step. Signed CI execution has not yet been tested with real GitHub secrets.
