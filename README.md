# LM Studio + OpenCode Backup: 48 GB MacBook Pro

This folder backs up the 48 GB Apple Silicon MacBook Pro local agentic coding setup.

Active profile:

- LM Studio local server at `127.0.0.1:1234`
- Fast default OpenCode model: `lmstudio/local-fast`
- Qwen coding OpenCode model: `lmstudio/local-coder`
- Fast model source: `mlx-community/Llama-3.2-3B-Instruct-4bit`, loaded as `local-fast`
- Chat/coding model source: `froggeric/qwen3.6-27b-mlx-8bit`, loaded as `local-coder`
- Local model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- MLX/safetensors 8-bit, about `28 GB`, about `35 GB` minimum system memory
- OpenCode Qwen context/output: `32768` / `4096`
- OpenCode fast context/output: `32768` / `1024`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- OpenCode MCPs: `context7`, `gh_grep`, `local_code_index`, `local_dev_tools`
- Default agent: `fast`, a no-tool quick-answer route that prevents local Qwen from hanging on trivial turns
- Qwen agents: `build`, `plan`, `indexer`, `codebase-researcher`, `debugger`, `test-runner`, `code-reviewer`, `doc-researcher`, `security-auditor`
- Slash commands: `/explain`, `/research`, `/debug`, `/test`, `/review`, `/docs`, `/security`, `/index`, `/implement`
- LSP entries: `typescript`, `eslint`

Model weights are not copied here. The repo stores model identifiers, runtime package metadata, scripts, MCPs, and docs so LM Studio remains the place that owns model downloads and updates.

## Source Of Truth

All upgradeable setup variables live in:

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/config/profile-48gb.env
```

Edit that file first when changing the target username/home, chat model, model path, context, output tokens, LM Studio host/port, embedding model, OpenCode paths, RAG database, launch env, LSP commands, or LM Studio MLX runtime package URLs/checksums.

Then update `config/opencode.json` to match and run:

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/validate-profile-sync.sh
```

The old 24 GB profile is preserved as reference at `config/profile-24gb.env` and `reference/PLAN-24GB-legacy.md`.

## Lessons Baked In

- Do not manually swap the loaded LM Studio model for OpenCode. The setup requires stable aliases: `local-fast`, `local-coder`, and the embedding model must all be visible from `/v1/models`.
- Qwen stays the protected 48 GB `local-coder` implementation model, but it is no longer the default interactive agent. The default `fast` route handles short no-tool turns quickly.
- The `build` agent denies MCP tool namespaces by default to avoid repeated `local_code_index` and `local_dev_tools` loops. Use `/research` for MCP-backed discovery and `/implement` or `Build` for Qwen-backed edits.
- Qwen must receive the `<|think_off|>` prelude from `config/qwen36-instructions.md`; `/no_think` was not enough for this LM Studio template.
- `/explain` is intentionally fast and no-tool. For exact repository evidence, use `/research`.

## Restore On The 48 GB Mac

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/install-opencode-config.sh
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/seed-rag.sh
```

Restart OpenCode Desktop after installing the config.

If OpenCode is stuck in a long running turn, quit it before reinstalling. Then run `ensure-lmstudio-models.sh` and verify that `/v1/models` includes `local-fast`, `local-coder`, and `text-embedding-nomic-embed-text-v1.5` before reopening OpenCode.

If LM Studio's MLX runtime is missing its signed CPython vendor layer, run:

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/repair-lmstudio-mlx-runtime.sh
```

## Validate

Static validation, useful before running on a 48 GB host:

```bash
jq . /Users/oiqbal/AndroidStudioProjects/llm-opencode/config/opencode.json >/dev/null
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/validate-profile-sync.sh
SMOKE_SKIP_HARDWARE=1 SMOKE_SKIP_LMSTUDIO=1 SMOKE_SKIP_LAUNCHCTL=1 /Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/smoke-test.sh
```

Full validation on the 48 GB Mac:

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/smoke-test.sh
```

The full smoke test loads the 32K `local-fast` and `local-coder` aliases, checks local-only binding, verifies fast no-tool generation, verifies Qwen is loaded and configured with `<|think_off|>`, validates embeddings, exercises local MCPs, checks remote MCP reachability, and validates the OpenCode agent/command/LSP shape. Direct Qwen generation is intentionally opt-in with `SMOKE_QWEN_GENERATION=1` because the restored router avoids using Qwen for trivial no-tool turns.

## Update This Backup From A 48 GB Live Setup

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/backup-current-setup.sh
```

That command refuses to copy a live OpenCode config whose model does not match the active profile unless `BACKUP_ALLOW_PROFILE_MISMATCH=1` is set.
