# 48 GB macOS Local Agentic Coding Setup

## Summary

This is the concrete setup for a 48 GB Apple Silicon MacBook Pro using LM Studio and OpenCode Desktop with stable local model routing:

- `mlx-community/Llama-3.2-3B-Instruct-4bit` loaded as `local-fast` for the default fast/no-tool agent.
- `froggeric/qwen3.6-27b-mlx-8bit` loaded as `local-coder` for Qwen-backed implementation, planning, research, indexing, debugging, review, docs, tests, and security agents.

The OpenCode side is configured as a full local agentic coding environment with local RAG, local dev utilities, current docs/examples MCPs, TypeScript and ESLint LSP entries, subagents, slash commands, and guarded permissions. The default path is deliberately small and no-tool so trivial prompts do not wake Qwen or expose broad MCP schemas.

## Components

- Profile variables: `/Users/oiqbal/AndroidStudioProjects/llm-opencode/config/profile-48gb.env`
- LM Studio app: `/Applications/LM Studio.app`
- OpenCode app: `/Applications/OpenCode.app`
- OpenCode config: `~/.config/opencode/opencode.json`
- Qwen instruction prelude: `~/.config/opencode/qwen36-instructions.md`
- Local workflow instruction: `~/.config/opencode/local-coding-workflow.md`
- Default model source: `mlx-community/Llama-3.2-3B-Instruct-4bit`
- Coding model source: `froggeric/qwen3.6-27b-mlx-8bit`
- Coding model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- Quantization/runtime: MLX/safetensors 8-bit
- Qwen context/output: `32768` / `4096`
- Fast context/output: `32768` / `1024`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- LM Studio API: `http://127.0.0.1:1234/v1`
- Local index DB: `~/.cache/opencode/local-code-index.sqlite3`
- LaunchAgent: `~/Library/LaunchAgents/com.oiqbal.opencode.env.plist`

## OpenCode Features

- Provider: LM Studio local OpenAI-compatible API
- MCPs:
  - `context7`: remote current docs
  - `gh_grep`: remote GitHub code examples
  - `local_code_index`: local semantic code index over OpenCode projects
  - `local_dev_tools`: project overview, git status, bounded command execution, debug command tagging, file tree, dependency summary
- Agents:
  - `fast`
  - `explain`
  - `indexer`
  - `build`
  - `plan`
  - `codebase-researcher`
  - `debugger`
  - `test-runner`
  - `code-reviewer`
  - `doc-researcher`
  - `security-auditor`
- Slash commands:
  - `/explain`
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
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/install-opencode-config.sh
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/seed-rag.sh
open -a OpenCode
```

If OpenCode is stuck in a repeating tool turn, quit OpenCode before installing. The restore path is expected to start from a clean OpenCode process with these LM Studio aliases loaded: `local-fast`, `local-coder`, and `text-embedding-nomic-embed-text-v1.5`.

If the MLX engine fails with missing `libpython3.11.dylib`, run:

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/repair-lmstudio-mlx-runtime.sh
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
```

## Smoke Test

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/smoke-test.sh
```

Expected:

- OpenCode config parses with `jq`.
- Profile and config are in sync.
- LM Studio exposes `local-fast`, `local-coder`, and the embedding model under stable aliases.
- LM Studio listens only on `127.0.0.1:1234`.
- Fast no-tool generation returns quickly.
- Qwen is loaded and the installed instruction prelude contains `<|think_off|>`.
- Optional `SMOKE_QWEN_GENERATION=1` verifies direct Qwen generation without `reasoning_content`; keep it opt-in because the default router avoids Qwen for trivial no-tool turns.
- Embeddings endpoint returns a `768`-dimension vector.
- Local MCPs list expected tools; `local_dev_tools` blocks destructive commands.
- Remote MCP endpoints respond.
- OpenCode config contains the expected four MCPs, eleven agents, nine commands, and two LSP entries.

## Routing Rules

- `fast` is the default agent and denies tools. It is for quick direct answers and sanity checks.
- `/explain` is also fast/no-tool. It should avoid guessing about project-specific behavior and should point to `/research` when exact repo evidence is needed.
- `/research` uses local RAG and read-only repo tools. It should perform one targeted semantic search, then read concrete files instead of repeating the same MCP call.
- `/implement` and `Build` use Qwen through `local-coder`; the `build` agent denies MCP namespaces directly so Qwen does not receive broad MCP schemas during normal edits.
- `/index` uses the dedicated `indexer` agent so index maintenance still has local_code_index access even though Build denies MCP namespaces.
