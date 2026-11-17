# Changelog

Versions follow Semantic Versioning. Pre-1.0 releases are experimental.

## Unreleased

- Optional whole-draft keyboard-layout recovery after typing pauses, using enabled
  macOS layouts and conservative local spelling evidence; disabled by default.
- Dedicated consent, pause/exclusion controls, source switching and guarded Undo.
  Automatic repair requires direct Accessibility value writes; paste-only editors
  retain manual rewriting. Signed-app/editor validation remains pending.
- Compatibility guidance, more specific text-access errors, processing stages and
  manually copyable, content-free operation timings.
- Structured optional feedback fields and refreshed privacy/test documentation.

## [0.2.0-beta.8](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.7...v0.2.0-beta.8) (2026-11-11)


### Features

* **macos:** add opt-in launch at login ([#36](https://github.com/vladkampov/Inigo/issues/36)) ([87be6e6](https://github.com/vladkampov/Inigo/commit/87be6e6a01e8a098e3a353485d7c1d2c0218136a))


### Bug Fixes

* isolate stable update publishing and document release gates ([#29](https://github.com/vladkampov/Inigo/issues/29)) ([089bc93](https://github.com/vladkampov/Inigo/commit/089bc9373cc98d93975cbb158b71a5112ae8d1c7))
* prevent stale model downloads and recover damaged files ([#30](https://github.com/vladkampov/Inigo/issues/30)) ([9e21219](https://github.com/vladkampov/Inigo/commit/9e212199969202dde6a81907f42b822635762f4f))

## [0.2.0-beta.7](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.6...v0.2.0-beta.7) (2026-11-06)

### Release validation

- Version-only beta to verify signed download, installation, and relaunch from beta.6. No application behavior changes.

## [0.2.0-beta.6](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.5...v0.2.0-beta.6) (2026-11-06)


### Features

* enable beta updates and preserve translation targets ([#17](https://github.com/vladkampov/Inigo/issues/17)) ([145785f](https://github.com/vladkampov/Inigo/commit/145785fdad0a403a2bdb9c14830c40d9f5128453))

## [0.2.0-beta.5](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.4...v0.2.0-beta.5) (2026-11-06)


### Bug Fixes

* validate and explicitly select CI signing identity ([#15](https://github.com/vladkampov/Inigo/issues/15)) ([b337e08](https://github.com/vladkampov/Inigo/commit/b337e08896f9297c40d0e4abf44edd45793cb394))

## [0.2.0-beta.4](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.3...v0.2.0-beta.4) (2026-11-06)


### Bug Fixes

* resolve unpublished release drafts ([#14](https://github.com/vladkampov/Inigo/issues/14)) ([fda5ad4](https://github.com/vladkampov/Inigo/commit/fda5ad43ad807d7cee48e71d2f8857b5a9c45671))

## [0.2.0-beta.3](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.2...v0.2.0-beta.3) (2026-11-06)


### Features

* automate beta versioning and signed release preparation ([#7](https://github.com/vladkampov/Inigo/issues/7)) ([5d01f23](https://github.com/vladkampov/Inigo/commit/5d01f23da5829417b7a93a2a3756d05d0ae14af0))


### Bug Fixes

* enforce invocation privacy and retire browser extensions ([#11](https://github.com/vladkampov/Inigo/issues/11)) ([098b9a2](https://github.com/vladkampov/Inigo/commit/098b9a2c328acd71bb850bfaf9a8f8ca9846cd56))
* make product language inclusive and document beta readiness ([#9](https://github.com/vladkampov/Inigo/issues/9)) ([102f359](https://github.com/vladkampov/Inigo/commit/102f3594918df5b2c12e8701f4b99de740cfa75f))

## [0.2.0-beta.2](https://github.com/vladkampov/Inigo/compare/v0.2.0-beta.1...v0.2.0-beta.2) (2026-11-06)


### Features

* automate beta versioning and signed release preparation ([#7](https://github.com/vladkampov/Inigo/issues/7)) ([5d01f23](https://github.com/vladkampov/Inigo/commit/5d01f23da5829417b7a93a2a3756d05d0ae14af0))


### Bug Fixes

* enforce invocation privacy and retire browser extensions ([#11](https://github.com/vladkampov/Inigo/issues/11)) ([098b9a2](https://github.com/vladkampov/Inigo/commit/098b9a2c328acd71bb850bfaf9a8f8ca9846cd56))
* make product language inclusive and document beta readiness ([#9](https://github.com/vladkampov/Inigo/issues/9)) ([102f359](https://github.com/vladkampov/Inigo/commit/102f3594918df5b2c12e8701f4b99de740cfa75f))

## 0.2.0-beta.1 — 2026-11-06
- Local model selection, GGUF import and loopback server connections.
- Comparative multilingual model benchmark.
- Explicit translation targets and wrong-language output checks.
- Safer verification of delayed editor insertions.
- Signed-update integration, repository community files and release tooling.
- Content-free, opt-in error reporting integration; disabled until configured.

## 0.1.0 — Personal prototype
- Native menu-bar refinement and translation, configurable shortcuts.
- Onboarding, local processing, protected text validation and guarded Undo.
- 24 interface languages and translation targets, including RTL layouts.
