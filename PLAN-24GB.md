# 24 GB MacBook Pro Local Coding LLM Setup

## Summary

This is the concrete setup for `/Users/ohmz`'s 24 GB Apple Silicon MacBook Pro. It uses LM Studio and OpenCode Desktop with one local chat model and one local embedding model.

Use this setup when duplicating or restoring the current 24 GB machine. Do not substitute the 48 GB Qwen3.6 8-bit plan unless moving to a 48 GB Mac.

## Components

- Profile variables: `/Users/ohmz/StudioProjects/llm-opencode/config/profile-24gb.env`
- LM Studio app: `/Applications/LM Studio.app`
- OpenCode app: `/Applications/OpenCode.app`
- OpenCode config: `~/.config/opencode/opencode.json`
- Chat model: `qwen3.6-27b`
- Chat model path: `NexVeridian/Qwen3.6-27B-3bit`
- Quantization/runtime: MLX/safetensors 3-bit
- Context: `12288`
- Output: `768`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- LM Studio API: `http://127.0.0.1:1234/v1`

## OpenCode Features

- Provider: LM Studio local OpenAI-compatible API
- MCPs:
  - `local_code_index`: local semantic code index over OpenCode projects
  - `local_dev_tools`: project status and safe named checks
  - `context7`: compact proxy to Context7 docs
  - `gh_grep`: compact proxy to grep.app GitHub examples
- Agents:
  - `build`
  - `plan`
  - `debug`
  - `review`
- Slash commands:
  - `/index`
  - `/reindex`
  - `/search-index`
  - `/debug`
  - `/review`
  - `/docs`
- LSP:
  - `sourcekit-lsp` with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  - TypeScript support is provided by OpenCode/project TypeScript dependency where available.

## Restore Steps

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/install-opencode-config.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/seed-rag.sh
open -a OpenCode
```

If the MLX engine fails with missing `libpython3.11.dylib`, run:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/repair-lmstudio-mlx-runtime.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
```

## Smoke Test

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh
```

Expected:

- OpenCode config parses with `jq`.
- LM Studio models are loaded.
- LM Studio listens only on `127.0.0.1:1234`.
- Chat completion returns `OK`.
- Embeddings endpoint returns a vector.
- All local/proxy MCPs list tools; proxy MCPs also complete a minimal remote call.
- SourceKit LSP is available.

## Maintenance

Model, context, runtime, MCP path, RAG, and LSP values should be changed first in:

```bash
/Users/ohmz/StudioProjects/llm-opencode/config/profile-24gb.env
```

After changing the profile or OpenCode config, run:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh
```

After changing the live setup:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/backup-current-setup.sh
```

Then rerun the smoke test.
