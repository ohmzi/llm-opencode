# Agent Instructions

This repository is a backup and restore kit for `/Users/ohmz`'s 24 GB MacBook Pro LM Studio + OpenCode setup.

## Rules

- Preserve this as a 24 GB profile.
- Do not generalize paths unless explicitly asked.
- Do not copy `.safetensors`, `.gguf`, or other model-weight files into this repo.
- Keep model access updateable through LM Studio model identifiers and scripts.
- Treat `config/profile-24gb.env` as the source of truth for model, system, runtime, and path variables.
- Keep `config/profile-24gb.env` and `config/opencode.json` in sync; run `scripts/validate-profile-sync.sh` after either changes.
- Prefer updating this backup first, then run `scripts/install-opencode-config.sh` to sync live OpenCode config.
- Validate changes with `scripts/smoke-test.sh`.

## Main Files

- `config/opencode.json`: backed-up OpenCode global config.
- `config/profile-24gb.env`: editable 24 GB profile variables for model, context, paths, runtime packages, MCPs, and LSP.
- `mcp/local_code_index.py`: local semantic RAG MCP.
- `mcp/local_dev_tools.py`: compact local project/git/check helper MCP.
- `mcp/remote_mcp_proxy.py`: compact proxy MCP for Context7 and grep.app.
- `scripts/ensure-lmstudio-models.sh`: loads chat and embedding models.
- `scripts/repair-lmstudio-mlx-runtime.sh`: repairs the LM Studio MLX CPython/vendor runtime layer if the local runtime cache is incomplete.
- `scripts/validate-profile-sync.sh`: checks profile variables against `config/opencode.json`.
- `scripts/smoke-test.sh`: regression test for the full local setup.

## Workflow

1. Inspect the current live setup before changing this backup.
2. Make focused changes to `config/profile-24gb.env`, `config/opencode.json`, scripts, or docs.
3. Run `jq . config/opencode.json`.
4. Run `scripts/validate-profile-sync.sh`.
5. Run `scripts/smoke-test.sh`.
6. Summarize exactly what changed and whether validation passed.
