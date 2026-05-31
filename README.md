# LM Studio + OpenCode Backup: 48 GB MacBook Pro

This folder backs up the 48 GB Apple Silicon MacBook Pro local agentic coding setup.

Active profile:

- LM Studio local server at `127.0.0.1:1234`
- One visible OpenCode model: `lmstudio/local-coder`
- Chat model source: `froggeric/qwen3.6-27b-mlx-8bit`
- Local model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- MLX/safetensors 8-bit, about `28 GB`, about `35 GB` minimum system memory
- OpenCode context: `32768`
- OpenCode output: `4096`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- OpenCode MCPs: `context7`, `gh_grep`, `local_code_index`, `local_dev_tools`
- Agents: `build`, `plan`, `codebase-researcher`, `debugger`, `test-runner`, `code-reviewer`, `doc-researcher`, `security-auditor`
- Slash commands: `/research`, `/debug`, `/test`, `/review`, `/docs`, `/security`, `/index`, `/implement`
- LSP entries: `typescript`, `eslint`

Model weights are not copied here. The repo stores model identifiers, runtime package metadata, scripts, MCPs, and docs so LM Studio remains the place that owns model downloads and updates.

## Source Of Truth

All upgradeable setup variables live in:

```bash
/Users/ohmz/StudioProjects/llm-opencode/config/profile-48gb.env
```

Edit that file first when changing the target username/home, chat model, model path, context, output tokens, LM Studio host/port, embedding model, OpenCode paths, RAG database, launch env, LSP commands, or LM Studio MLX runtime package URLs/checksums.

Then update `config/opencode.json` to match and run:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh
```

The old 24 GB profile is preserved as reference at `config/profile-24gb.env` and `reference/PLAN-24GB-legacy.md`.

## Restore On The 48 GB Mac

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/install-opencode-config.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/seed-rag.sh
```

Restart OpenCode Desktop after installing the config.

If LM Studio's MLX runtime is missing its signed CPython vendor layer, run:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/repair-lmstudio-mlx-runtime.sh
```

## Validate

Static validation, useful before running on a 48 GB host:

```bash
jq . /Users/ohmz/StudioProjects/llm-opencode/config/opencode.json >/dev/null
/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh
SMOKE_SKIP_HARDWARE=1 SMOKE_SKIP_LMSTUDIO=1 SMOKE_SKIP_LAUNCHCTL=1 /Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh
```

Full validation on the 48 GB Mac:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh
```

The full smoke test loads the 32K `local-coder` model, checks local-only binding, verifies Qwen prelude generation, checks compaction-style prompt rendering, validates embeddings, exercises local MCPs, checks remote MCP reachability, and validates the OpenCode agent/command/LSP shape.

## Update This Backup From A 48 GB Live Setup

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/backup-current-setup.sh
```

That command refuses to copy a live OpenCode config whose model does not match the active profile unless `BACKUP_ALLOW_PROFILE_MISMATCH=1` is set.
