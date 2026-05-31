# 96 GB Ubuntu RTX 3090 Local Agentic Coding Setup

## Summary

This is the opt-in Linux/NVIDIA setup for an Ubuntu workstation with an Intel i9 13th gen CPU, 96 GB
DDR5 RAM, and one RTX 3090. It keeps the OpenCode workflow from the 48 GB Mac profile: one visible
`lmstudio/local-coder` model, Qwen prelude, local RAG, local dev tools, remote docs/examples MCPs,
TypeScript and ESLint LSPs, subagents, slash commands, and guarded permissions.

The model runtime changes from Mac MLX/safetensors to LM Studio's Linux llama.cpp/GGUF runtime:

`unsloth/Qwen3.6-27B-GGUF@UD-Q5_K_XL` loaded as `local-coder`.

Model reference checked on 2026-05-31:

- Hugging Face model: https://huggingface.co/unsloth/Qwen3.6-27B-GGUF
- Target file: `Qwen3.6-27B-UD-Q5_K_XL.gguf`
- File size: about `20 GB`
- SHA256: `ac310abf2895aa397121bad6c0be89466af41f0f1606a21c1131b110eeb19d0e`
- License: Apache 2.0

The RTX 3090 has 24 GB VRAM, so this profile defaults to a stable `16384` token context with
fallbacks at `12288` and `8192`. If `lms load --estimate-only` and `nvidia-smi` show enough
headroom, try `24576` or `32768` later, then update both `config/profile-96gb-ubuntu-nvidia.env` and
`config/opencode-96gb-ubuntu-nvidia.json`.

## Components

- Profile variables: `config/profile-96gb-ubuntu-nvidia.env`
- OpenCode config: `config/opencode-96gb-ubuntu-nvidia.json`
- Linux install helper: `scripts/install-opencode-config-linux.sh`
- Linux model helper: `scripts/ensure-lmstudio-models-linux.sh`
- Qwen instruction prelude: `~/.config/opencode/qwen36-instructions.md`
- Local workflow instruction: `~/.config/opencode/local-coding-workflow.md`
- Chat model: `Qwen3.6-27B-UD-Q5_K_XL.gguf`
- Quantization/runtime: GGUF `UD-Q5_K_XL` through LM Studio llama.cpp on NVIDIA
- Context: `16384`
- Output: `4096`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`
- LM Studio API: `http://127.0.0.1:1234/v1`
- Local index DB: `~/.cache/opencode/local-code-index.sqlite3`

## Ubuntu Prerequisites

Install the normal local development tooling:

```bash
sudo apt update
sudo apt install -y git curl jq zsh python3 python3-venv python3-pip nodejs npm ripgrep lsof
```

Install NVIDIA drivers so this passes:

```bash
nvidia-smi
```

Install LM Studio for Linux, open it once, and confirm `lms` is available:

```bash
lms --help
lms server start
```

LM Studio's CLI ships with the app. The Hugging Face LM Studio docs also support downloading a full
Hugging Face URL with an `@` quantization suffix, which is what this profile uses.

## Install OpenCode Config

From this backup repo on the Ubuntu workstation:

```bash
cd ~/StudioProjects/llm-opencode
export OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env"
export OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json"
scripts/install-opencode-config-linux.sh
```

If the Ubuntu username is not `ohmz`, update `TARGET_USER`, `TARGET_HOME`, and the `/home/ohmz/...`
paths in `config/opencode-96gb-ubuntu-nvidia.json` before installing.

For GUI-launched OpenCode Desktop, make sure these environment variables are available to your
desktop session:

```bash
mkdir -p ~/.config/environment.d
printf '%s\n' \
  'OPENCODE_ENABLE_EXA=1' \
  'OPENCODE_EXPERIMENTAL_LSP_TOOL=true' \
  > ~/.config/environment.d/opencode.conf
systemctl --user import-environment OPENCODE_ENABLE_EXA OPENCODE_EXPERIMENTAL_LSP_TOOL || true
```

Log out and back in if your desktop environment does not pick up `environment.d` changes
immediately.

## Download And Load Models

Use the helper:

```bash
export OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env"
scripts/ensure-lmstudio-models-linux.sh
```

Equivalent manual flow:

```bash
lms server start
lms get https://huggingface.co/unsloth/Qwen3.6-27B-GGUF@UD-Q5_K_XL --gguf
lms get text-embedding-nomic-embed-text-v1.5 --gguf
lms ls
```

Then load the downloaded Qwen model key as:

```bash
lms load <qwen_model_key> \
  --identifier local-coder \
  --context-length 16384 \
  --gpu max \
  --ttl 3600

lms load text-embedding-nomic-embed-text-v1.5 \
  --identifier text-embedding-nomic-embed-text-v1.5 \
  --ttl 3600
```

Watch VRAM during first load and first request:

```bash
nvidia-smi
```

If LM Studio cannot load at 16K with `--gpu max`, retry `12288`, then `8192`. If it loads but spills
heavily to system RAM, keep it if the speed is acceptable or move down one context step.

## Validate

Static validation:

```bash
jq . config/opencode-96gb-ubuntu-nvidia.json >/dev/null
OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
  OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
  scripts/validate-profile-sync.sh
zsh -n scripts/*.sh scripts/lib/profile.sh
SMOKE_SKIP_HARDWARE=1 SMOKE_SKIP_LMSTUDIO=1 SMOKE_SKIP_LAUNCHCTL=1 \
  OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
  OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
  scripts/smoke-test.sh
```

Live validation on the Ubuntu target:

```bash
OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
  OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
  scripts/smoke-test.sh
```

Expected:

- OpenCode config parses with `jq`.
- Profile and config are in sync.
- LM Studio loads `local-coder` at the configured context. If the helper falls back to `12288` or
  `8192`, update the profile and OpenCode config to that context, then rerun validation.
- LM Studio listens only on `127.0.0.1:1234`.
- Qwen prelude generation returns `OK local-coder` without `reasoning_content`.
- Compaction-style prompt rendering does not crash or produce a template error.
- Embeddings endpoint returns a `768`-dimension vector.
- Local MCPs list expected tools and `local_dev_tools` blocks destructive commands.
- Remote MCP endpoints respond.
- OpenCode config contains the expected four MCPs, eight agents, eight commands, and two LSP
  entries.

## Keep The Baseline

Do not replace `config/profile-48gb.env` or `config/opencode.json` with this Linux profile unless
you intentionally want to change the default Mac backup. The Ubuntu setup is selected with:

```bash
OPENCODE_BACKUP_PROFILE=config/profile-96gb-ubuntu-nvidia.env
OPENCODE_BACKUP_CONFIG=config/opencode-96gb-ubuntu-nvidia.json
```

Do not copy `.gguf` model weights into this repository. Store only model identifiers, URLs,
checksums, profile variables, scripts, and docs.
