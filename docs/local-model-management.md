# Local models

See benchmarks/report.md for measured EN/PL/UK quality and speed.
9B is now recommended at 24 GB+, 4B at 16 GB, and 2B below 16 GB.
Only M5/24 GB has been measured; smaller tiers are capacity estimates.
Existing model choices are persisted and never switched automatically.

Pinned Q4_K_M downloads: 2B 1.28 GB, 4B 2.74 GB, 9B 5.68 GB.
All are SHA-256 verified. Weights are separate from the app and MIT source license.

Advanced settings accept GGUF v2/v3 compatible with llama.cpp, or an
OpenAI-compatible loopback server. A synthetic protected-token rewrite must pass
before saving. GGUF files remain at their original paths. The app never kills
user-owned servers. Optional credentials live in Keychain.

Loopback does not guarantee that an external server will never forward requests.
This limitation is disclosed before connection. No remote endpoints or automatic
cloud fallback are supported. Imported MLX directories need a different runtime.

Refinement and translation guard confidently detected language mismatches, retry
once, and reject repeated wrong-language results. Short/mixed text is ambiguous.
No automated check proves semantic fidelity. Review every important rewrite.
