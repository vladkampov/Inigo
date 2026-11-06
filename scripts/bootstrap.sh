#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
NODE_BIN="${INIGO_NODE:-$(command -v node || true)}"
if [ -z "$NODE_BIN" ]; then echo "Install Node 22+ or set INIGO_NODE for optional bridge tests." >&2; exit 1; fi
export PATH="$(dirname "$NODE_BIN"):$PATH"
npm ci --prefix CloudBridge
npm run build --prefix CloudBridge
mkdir -p .runtime/llama
if [ ! -x .runtime/llama/llama-b12172/llama-server ]; then
  curl -fL https://github.com/ggml-org/llama.cpp/releases/download/b12172/llama-b12172-bin-macos-arm64.tar.gz -o .runtime/llama.tar.gz
  echo "277b3e82da71fb34478657e6eeaf6c9b714a37b71f8adec44603689fa75f2ae5  .runtime/llama.tar.gz" | shasum -a 256 -c -
  tar -xzf .runtime/llama.tar.gz -C .runtime/llama
fi
