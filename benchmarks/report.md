# Historical model comparison

The input corpus has been replaced with fictional everyday scenarios. Saved text
payloads were removed; the measurements below belong to the retired corpus.
This report does not establish quality or speed on the current fixtures.

Run: 2026-11-06, Apple M5, **24 GiB unified memory**, macOS 26.6.2,
llama.cpp b12172, Q4_K_M, 8,192-token context, temperature 0.1,
thinking disabled, serial inference, two repetitions of 21 retired cases.

| Model | Refinement median / p95 | Translation median / p95 | Peak process RSS |
|---|---:|---:|---:|
| 2B | 0.87 / 1.21 s | 0.99 / 1.24 s | 1.93 GB |
| 4B | 1.97 / 3.13 s | 2.20 / 2.63 s | 4.10 GB |
| 9B | 3.97 / 6.52 s | 4.19 / 5.07 s | 7.04 GB |

Startup-to-health: approximately 0.51 / 0.51 / 1.02 seconds, with potentially
warm filesystem caches. Not a cold-boot guarantee. RSS excludes some shared/GPU
allocations. This is one occupied personal Mac, not a controlled thermal lab.

## Quality review

Review method: inspect both repetitions against the source for (1) facts, dates,
tense and uncertainty; (2) target/source language; (3) grammar and naturalness;
(4) protected-token preservation; (5) resistance to reference-text instructions.
This is an assistant editorial review, **not an independent native-speaker rating**.
No opaque composite score is used to hide severe failures.

- **2B:** historical review found tense, language and grammar errors.
- **4B:** historical review found meaning changes, invented timing and failures
  to ignore language-changing instructions in quoted context.
- **9B:** historical review found fewer such errors, but terminology and wording
  were still imperfect. These judgments cannot be independently reconstructed
  from the redacted measurement files and require a new run for current evidence.

Protected-token checks: 2B passed 39/42 outputs, 4B 41/42, 9B 42/42. Only six
outputs per model actually contained protected objects; failures were 3/6, 1/6,
0/6 respectively. The app rejects missing/reordered tokens, so these become
failed rewrites rather than damaged mentions. “BANANA” absence alone is not a
valid injection pass; actual language was reviewed above.

## Recommendation

Recommend **9B on 24 GB+ Macs** for this EN/PL/UK workload, based on the observed
quality advantage and roughly four-second median latency. It can exceed the
five-second goal. Keep 4B as a faster lower-memory option and 2B as a lightweight
compromise, not equivalent-quality substitutes. Other chips/memory tiers have
not been measured. Keep existing explicit selections unchanged.

The source now also checks refinement language and retries/rejects confident
language changes. This guard was added in response to the benchmark; the raw
comparison above is from the frozen prompt snapshot, before that new guard.
No guard can prove semantic fidelity. Public release still needs native-speaker
review, technical-term preservation work, and longer/ambiguous-draft evaluation.
