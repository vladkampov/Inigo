# Model comparison

Synthetic English, Polish and Ukrainian corpus: 12 refinement cases, all 6
translation directions, and 3 hostile-context cases. Two repetitions per model,
The current fixtures use fictional everyday scenarios. Production prompt snapshot:
prompts.json. Historical result files retain measurements only; their text payloads
have been removed. They are not results for the current corpus. Rerun the benchmark
before making quality or performance claims about the replacement fixtures.

Run:
1. `python3 scripts/download-benchmark-models.py` — pinned weights + SHA-256.
2. Export production prompts if intentionally testing changed instructions:
   `swift run InigoBench export benchmarks/cases.json > benchmarks/prompts.json`.
3. `python3 scripts/benchmark-models.py` — serial models, no concurrent inference.
4. Read outputs as well as metrics. Exact-string “missing” flags need human
   interpretation: translating a month name is not an error.

The run measures raw first-attempt model output. Application token and language
guards can reject/retry it; those costs are not included. Startup means process
launch to health-ready with the OS file cache potentially warm, not a disk-cold
measurement. Process RSS is not total Metal/unified-memory use. Short-message
figures do not represent long drafts. Native-speaker review remains necessary.

See report.md for historical interpretation and results/*.json for retained measurements.
