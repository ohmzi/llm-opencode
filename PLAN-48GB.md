# 48 GB macOS Local Agentic Coding Setup

## Summary

This is the concrete setup for a 48 GB Apple Silicon MacBook Pro using LM Studio and OpenCode Desktop with one primary local coding model:

`froggeric/qwen3.6-27b-mlx-8bit` loaded as `local-coder`.

The OpenCode side is configured as a full local agentic coding environment with local RAG, local dev utilities, current docs/examples MCPs, TypeScript and ESLint LSP entries, subagents, slash commands, and guarded permissions.

## Components

- Profile variables: `/Users/ohmz/StudioProjects/llm-opencode/config/profile-48gb.env`
- LM Studio app: `/Applications/LM Studio.app`
- OpenCode app: `/Applications/OpenCode.app`
- OpenCode config: `~/.config/opencode/opencode.json`
- Qwen instruction prelude: `~/.config/opencode/qwen36-instructions.md`
- Local workflow instruction: `~/.config/opencode/local-coding-workflow.md`
- Chat model source: `froggeric/qwen3.6-27b-mlx-8bit`
- Chat model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- Quantization/runtime: MLX/safetensors 8-bit
- Context: `32768`
- Output: `4096`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- LM Studio API: `http://127.0.0.1:1234/v1`
- Local index DB: `~/.cache/opencode/local-code-index.sqlite3`
- LaunchAgent: `~/Library/LaunchAgents/com.ohmz.opencode.env.plist`

## OpenCode Features

- Provider: LM Studio local OpenAI-compatible API
- MCPs:
  - `context7`: remote current docs
  - `gh_grep`: remote GitHub code examples
  - `local_code_index`: local semantic code index over OpenCode projects
  - `local_dev_tools`: project overview, git status, bounded command execution, debug command tagging, file tree, dependency summary
- Agents:
  - `build`
  - `plan`
  - `codebase-researcher`
  - `debugger`
  - `test-runner`
  - `code-reviewer`
  - `doc-researcher`
  - `security-auditor`
- Slash commands:
  - `/research`
  - `/debug`
  - `/test`
  - `/review`
  - `/docs`
  - `/security`
  - `/index`
  - `/implement`
- LSP:
  - `typescript`
  - `eslint`

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
- Profile and config are in sync.
- LM Studio models are loaded.
- LM Studio listens only on `127.0.0.1:1234`.
- Qwen prelude generation returns `OK local-coder` without `reasoning_content`.
- Compaction-style prompt rendering does not crash or produce a Jinja error.
- Embeddings endpoint returns a `768`-dimension vector.
- Local MCPs list expected tools; `local_dev_tools` blocks destructive commands.
- Remote MCP endpoints respond.
- OpenCode config contains the expected four MCPs, eight agents, eight commands, and two LSP entries.
