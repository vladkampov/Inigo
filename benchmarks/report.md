# English, Polish and Ukrainian model comparison

Run: 2026-11-06, Apple M5, **24 GiB unified memory**, macOS 26.6.2,
llama.cpp b12172, Q4_K_M, 8,192-token context, temperature 0.1,
thinking disabled, serial inference, two repetitions of 21 synthetic cases.

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

- **2B:** quick English cleanup, but weak for this multilingual workload.
  Ukrainian→English changed future possibility into “could have delivered.”
  Ukrainian→Polish similarly changed future possibility into past tense.
  Several Ukrainian translations were nonsensical, and Polish bureaucracy
  examples contained grammatical errors. The Polish hostile-context case changed
  to mixed Polish/Russian in both runs.
- **4B:** useful speed, better basic translation, but serious meaning errors.
  Polish refinement moved the pilot to Q1 and omitted the tentative April date;
  one run invented “this week.” English→Ukrainian turned waiting until Q1 into
  finishing by Q1. Ukrainian→Polish used past tense. Both English hostile-context
  runs followed the quoted instruction to switch language.
- **9B:** best observed preservation of tentative delivery timing and substantially
  better Polish/Ukrainian wording. All six hostile-context outputs retained their
  source language. Still imperfect: English→Ukrainian translated the product name
  “Search,” English→Polish used an unnatural translation of “discovery,” and the
  Ukrainian follow-up added unnecessary specificity about timelines.

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
