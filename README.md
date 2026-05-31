# LM Studio + OpenCode Backup: 24 GB MacBook Pro

This folder backs up the exact local coding setup from this 24 GB Apple Silicon Mac.

It is intentionally not a generic setup. It preserves the working 24 GB profile:

- LM Studio local server at `127.0.0.1:1234`
- Chat model: `qwen3.6-27b`
- Local model path: `NexVeridian/Qwen3.6-27B-3bit`
- MLX/safetensors 3-bit
- OpenCode context: `12288`
- OpenCode output: `768`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- OpenCode MCPs: `local_code_index`, `local_dev_tools`, `context7`, `gh_grep`
- Agents: `build`, `plan`, `debug`, `review`
- Slash commands: `/index`, `/reindex`, `/search-index`, `/debug`, `/review`, `/docs`
- LSP: `sourcekit-lsp` with Xcode launch environment

Model weights are not copied here. The repo stores model identifiers and scripts so the models remain updateable through LM Studio.

## Source Of Truth

All upgradeable setup variables live in:

```bash
/Users/ohmz/StudioProjects/llm-opencode/config/profile-24gb.env
```

Edit that file first when changing the chat model, model path, context, output tokens, LM Studio host/port, embedding model, OpenCode paths, RAG database, LSP env, or LM Studio MLX runtime package URLs/checksums. Then update `config/opencode.json` to match and run:

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh
```

## Restore

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

```bash
jq . /Users/ohmz/StudioProjects/llm-opencode/config/opencode.json >/dev/null
/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh
/Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh
```

The smoke test loads the 12K chat model profile, checks local-only binding, verifies embeddings, exercises the local MCPs, makes minimal calls through the Context7 and grep.app proxy MCPs, and validates the SourceKit LSP config. If LM Studio's MLX runtime is missing the signed CPython vendor layer, `ensure-lmstudio-models.sh` calls the repair script first.

## Update This Backup From Live Setup

```bash
/Users/ohmz/StudioProjects/llm-opencode/scripts/backup-current-setup.sh
```

That command refreshes live OpenCode config, instructions, MCP scripts, and manifests. It does not overwrite the repo's helper scripts from live copies unless `BACKUP_LIVE_HELPERS=1` is set.

## Important Notes

- Keep this as the 24 GB profile. Do not replace it with the 48 GB Qwen3.6 8-bit plan.
- Do not commit or copy model weights into this folder.
- If LM Studio says no model is loaded, run `scripts/ensure-lmstudio-models.sh`.
- If OpenCode has stale failed sessions, start a fresh OpenCode session after restoring.
