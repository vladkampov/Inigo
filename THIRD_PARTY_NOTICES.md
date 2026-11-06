# Third-party notices

Inigo's own code is MIT-licensed. Dependencies retain their own licenses.

- llama.cpp b12172: MIT, https://github.com/ggml-org/llama.cpp
  Runtime license is bundled as Resources/Runtime/LLAMA-LICENSE.
- Sparkle 2.10.1: BSD-style license and bundled third-party notices,
  https://github.com/sparkle-project/Sparkle/blob/2.10.1/LICENSE
  Preserve the complete framework and distribution notices when packaging.
- Optional Qwen 3.5 2B/4B/9B model downloads: Apache-2.0 according to the pinned
  upstream repositories. Model weights are not part of the source or app download.
  https://huggingface.co/unsloth/Qwen3.5-2B-GGUF
  https://huggingface.co/unsloth/Qwen3.5-4B-GGUF
  https://huggingface.co/unsloth/Qwen3.5-9B-GGUF
- Optional CloudBridge source uses OpenAI SDK (Apache-2.0) and jose (MIT);
  it and Node are not included in the local-only application package.

Review upstream model cards and license changes before changing pinned revisions.
Do not redistribute models under Inigo's MIT license.
