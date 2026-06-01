# Agent Instructions

This repository is a backup and restore kit for local OpenCode agentic coding setups. The default
profile remains the 48 GB MacBook Pro LM Studio setup; the Ubuntu RTX 3090 Lucebox setup is opt-in.

## Rules

- Preserve this as the 48 GB `local-coder` Qwen3.6 MLX 8-bit profile unless explicitly asked otherwise.
- Preserve `local-fast` as the default no-tool OpenCode route and `local-coder` as the Qwen implementation route unless explicitly asked otherwise.
- Preserve the Ubuntu RTX 3090 Lucebox profile as opt-in unless explicitly asked to make it the default.
- Do not copy `.safetensors`, `.gguf`, `.bin`, `.ckpt`, or other model-weight files into this repo.
- Treat `config/profile-48gb.env` as the source of truth for model, system, runtime, path, launch env, MCP, RAG, and LSP variables.
- Keep `config/profile-48gb.env` and `config/opencode.json` in sync; run `scripts/validate-profile-sync.sh` after either changes.
- For Ubuntu RTX work, treat `config/profile-96gb-ubuntu-nvidia.env` and `config/opencode-96gb-ubuntu-nvidia.json` as a matched pair and pass both with `OPENCODE_BACKUP_PROFILE` and `OPENCODE_BACKUP_CONFIG`.
- Prefer updating this backup first, then run `scripts/install-opencode-config.sh` on the target 48 GB Mac.
- Do not run the default full live smoke test on a non-Mac target without selecting the intended profile. For Ubuntu RTX validation, run `OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" scripts/smoke-test.sh`.
- Do not run the full live smoke test on a 24 GB host. Use `SMOKE_SKIP_HARDWARE=1 SMOKE_SKIP_LMSTUDIO=1 SMOKE_SKIP_LAUNCHCTL=1 scripts/smoke-test.sh` for static/local checks there.

## Main Files

- `config/profile-48gb.env`: editable 48 GB profile variables for model, context, paths, runtime packages, MCPs, launch env, and LSP.
- `config/opencode.json`: backed-up OpenCode global config for `lmstudio/local-fast` default routing and `lmstudio/local-coder` Qwen implementation.
- `config/qwen36-instructions.md`: Qwen prelude with `<|think_off|>`.
- `config/local-coding-workflow.md`: OpenCode tool/agent workflow instructions.
- `config/opencode-launch-env.sh`: GUI launch environment script for web search and LSP.
- `config/com.oiqbal.opencode.env.plist`: LaunchAgent for persistent GUI env.
- `mcp/local_code_index.py`: local semantic RAG MCP.
- `mcp/local_dev_tools.py`: local project/git/execute/debug/dependency utility MCP.
- `mcp/remote_mcp_proxy.py`: legacy compatibility proxy for Context7 and grep.app.
- `scripts/ensure-lmstudio-models.sh`: downloads/loads fast, Qwen coding, and embedding model aliases.
- `scripts/repair-lmstudio-mlx-runtime.sh`: repairs the LM Studio MLX CPython/vendor runtime layer if the local runtime cache is incomplete.
- `scripts/validate-profile-sync.sh`: checks profile variables against `config/opencode.json`.
- `scripts/smoke-test.sh`: regression test for the full local setup.
- `config/profile-96gb-ubuntu-nvidia.env`: opt-in Ubuntu RTX 3090 Lucebox profile; Lucebox is primary, LM Studio is embedding-only in normal mode.
- `config/opencode-96gb-ubuntu-nvidia.json`: OpenCode config for `lucebox/luce-dflash` plus `lmstudio/local-coder` rollback.
- `PLAN-96GB-UBUNTU-NVIDIA.md`: Ubuntu setup, validation, and troubleshooting runbook.
- `scripts/ensure-lucebox-linux.sh`: builds `dflash_server` and downloads Lucebox target/draft GGUF files outside this repo.
- `scripts/install-lucebox-service-linux.sh`: installs the on-demand Lucebox backend and always-on autowake proxy user services.
- `scripts/lucebox-autowake-proxy.py`: local proxy on `127.0.0.1:18080` that wakes the backend on `127.0.0.1:18081`, clamps output tokens, and unloads after idle.

## Workflow

1. Make focused changes to `config/profile-48gb.env`, `config/opencode.json`, scripts, MCPs, or docs.
2. Run `jq . config/opencode.json`.
3. Run `scripts/validate-profile-sync.sh`.
4. Run `zsh -n scripts/*.sh scripts/lib/profile.sh`.
5. Run the static smoke test on non-48 GB hosts or the full smoke test on the 48 GB target.
6. Summarize exactly what changed and whether validation passed.

## Troubleshooting Lessons

- Stable LM Studio aliases are required: `local-fast`, `local-coder`, and `text-embedding-nomic-embed-text-v1.5`.
- The default agent should stay `fast` and no-tool; use `/implement` or `Build` for Qwen coding.
- Keep MCP-backed discovery on `/research`; broad MCP access on the default Qwen build path caused repeated tool loops.
- Keep `<|think_off|>` at the top of `config/qwen36-instructions.md`.

For Ubuntu RTX changes:

1. Edit `config/profile-96gb-ubuntu-nvidia.env`, `config/opencode-96gb-ubuntu-nvidia.json`, Linux scripts, MCPs, or docs.
2. Run `jq . config/opencode-96gb-ubuntu-nvidia.json`.
3. Run `OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" scripts/validate-profile-sync.sh`.
4. Run `zsh -n scripts/*.sh scripts/lib/profile.sh`.
5. Run `python3 -m py_compile scripts/lucebox-autowake-proxy.py mcp/local_code_index.py mcp/local_dev_tools.py`.
6. Run the Ubuntu-profile `scripts/smoke-test.sh` when live Lucebox/LM Studio validation is intended.
