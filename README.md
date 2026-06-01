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

An opt-in Ubuntu/NVIDIA profile is available for an i9 13th gen, 96 GB RAM, RTX 3090 workstation:

- Setup plan: `PLAN-96GB-UBUNTU-NVIDIA.md`
- Profile: `config/profile-96gb-ubuntu-nvidia.env`
- OpenCode config: `config/opencode-96gb-ubuntu-nvidia.json`
- Main model runtime: Lucebox DFlash through an autowake proxy on `127.0.0.1:18080`
- Main model: `lucebox/luce-dflash` backed by `Qwen3.6-27B-Q4_K_M.gguf` + `dflash-draft-3.6-q4_k_m.gguf`
- Rollback model: `lmstudio/local-coder`, kept configured but not auto-loaded in normal mode
- Embeddings: LM Studio `text-embedding-nomic-embed-text-v1.5` on `127.0.0.1:1234`, loaded with `--gpu off --ttl 3600`
- Default Lucebox context: `32768`
- Idle behavior: the proxy starts the real Lucebox backend on demand at `127.0.0.1:18081` and stops it after 1 hour without API traffic

Use it explicitly with:

```bash
OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
scripts/validate-profile-sync.sh
```

The default backup remains the 48 GB Mac profile.

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

The full smoke test follows the active profile. On the Mac profile it loads the 32K `local-fast` and `local-coder` aliases, verifies fast no-tool generation, and keeps direct Qwen generation opt-in with `SMOKE_QWEN_GENERATION=1`. On the Ubuntu Lucebox profile it checks the Lucebox autowake proxy and chat path, keeps LM Studio embedding-only, exercises local MCPs, checks remote MCP reachability, and validates the OpenCode agent/command/LSP shape.

## Update This Backup From A 48 GB Live Setup

```bash
/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/backup-current-setup.sh
```

That command refuses to copy a live OpenCode config whose model does not match the active profile unless `BACKUP_ALLOW_PROFILE_MISMATCH=1` is set.
