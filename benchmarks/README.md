# Model comparison

Synthetic English, Polish and Ukrainian corpus: 12 refinement cases, all 6
translation directions, and 3 hostile-context cases. Two repetitions per model,
126 outputs total. Production prompt snapshot: prompts.json. No real user writing.

Run:
1. `python3 scripts/download-benchmark-models.py` — pinned weights + SHA-256.
2. Export production prompts if intentionally testing changed instructions:
   `swift run InigoBench export benchmarks/cases.json > benchmarks/prompts.json`.
3. `python3 scripts/benchmark-models.py` — serial models, no concurrent inference.
4. Read outputs as well as metrics. Exact-string “missing” flags need human
   interpretation: translating Q1 to “first quarter” is not an error.

The run measures raw first-attempt model output. Application token and language
guards can reject/retry it; those costs are not included. Startup means process
launch to health-ready with the OS file cache potentially warm, not a disk-cold
measurement. Process RSS is not total Metal/unified-memory use. Short-message
figures do not represent long drafts. Native-speaker review remains necessary.

See report.md for interpretation and results/*.json for the full raw evidence.
