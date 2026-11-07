# Publication review — 2026-11-06

Scope: source publication and controlled beta testing, not general availability.
Status updated 2026-11-07; original source-review evidence is dated 2026-11-06.

## Source publication findings

- Reviewed tracked files and all fetched branch history with Gitleaks 8.30.1.
  No credential findings after a narrow exception for the deliberately public
  Sparkle verification key. Private signing/API keys, models, runtime binaries,
  build artifacts and local credential exports are not tracked.
- MIT license and dependency notices present. Separately downloaded models retain
  their upstream licenses. No model weights are redistributed in the repository.
- Benchmark cases use synthetic text and example.com links. Benchmark language
  identifiers remain to make the measured scope explicit; they are not a claim
  that other languages are unsupported or equally validated.
- Product/model guidance now welcomes all supported languages. All 24 catalogs
  retain their keys and placeholders. Human localization review is still needed.
- Model server requests are restricted to loopback, disable redirects/proxies;
  error reporting is off and has no configured endpoint. No usage analytics.
- Public visibility, enforced main rules, private vulnerability reporting, secret
  scanning/push protection and the main-only release environment were verified.
  All six initial Dependabot updates were reviewed and merged after successful CI;
  the OpenAI/jose lockfile conflict was resolved and retested. A source review and
  secret scan are not a full security audit.

## Before inviting a small beta group

1. Signed, notarized CI builds passed through beta.7. Repeat artifact validation
   for the actual release candidate; source changes are not automatically shipped.
2. Install the actual release ZIP on a second Mac: Gatekeeper, first-run permission,
   model download, offline rewrite, translation, shortcuts and Services.
3. Test the supported editor paths using synthetic text. Verify protected mentions
   and links stay functional or fall back; typing/cursor changes cancel safely;
   Undo never overwrites subsequent edits. Track exact OS/app versions.
4. Provide release notes with known limitations and a working issue-report route.
   No universal editor compatibility claim. Do not direct testers to source builds.
5. The beta feed is live; beta.6 → beta.7 installation/relaunch passed. Stable
   publishing is isolated, but the first stable artifact and migration remain untested.

## Before a broader launch

- Verify real N→N+1 Sparkle updates, rejection of tampered archives, offline behavior
  and recovery; keep beta and stable feeds separate.
- Expand native-speaker quality and interface review beyond the benchmark sample;
  test RTL/mixed scripts, VoiceOver, keyboard-only and reduced-motion flows.
- Test low-memory/thermal conditions, interrupted downloads and long drafts on
  more supported Apple Silicon/macOS combinations.
- Keep GitHub reporting routes and support limits clear. No dedicated conduct
  email is required for 1.0; disclose that private maintainer conduct reporting
  is unavailable. Security reports use private vulnerability reporting.
- Configure error reports only if wanted, after provider/retention disclosure and
  synthetic privacy verification. Monitoring is optional, not a beta requirement.
- Signed CI and the beta update path are verified. Clean-Mac onboarding/offline
  coverage and the stable-channel release gates remain incomplete.
