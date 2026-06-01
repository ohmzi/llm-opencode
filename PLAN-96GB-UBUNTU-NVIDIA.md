# 96 GB Ubuntu RTX 3090 Local Agentic Coding Setup

## Summary

This is the opt-in Linux/NVIDIA setup for an Ubuntu workstation with an Intel i9 13th gen CPU, 96 GB
DDR5 RAM, and one RTX 3090. It keeps the OpenCode workflow from the 48 GB Mac profile: Qwen prelude,
local RAG, local dev tools, remote docs/examples MCPs, TypeScript and ESLint LSPs, subagents, slash
commands, and guarded permissions.

The main model runtime changes from Mac MLX/safetensors to Lucebox DFlash:

`lucebox/luce-dflash` backed by `Qwen3.6-27B-Q4_K_M.gguf` and the matched Lucebox DFlash draft.

LM Studio stays running for embeddings only in normal mode. The old `lmstudio/local-coder` chat
provider remains in OpenCode as rollback, but the helper scripts do not auto-load that Qwen model
unless `LMSTUDIO_LOAD_CHAT_ROLLBACK=1` is set.

Model reference checked on 2026-05-31:

- Hugging Face target model: https://huggingface.co/unsloth/Qwen3.6-27B-GGUF
- Target file: `Qwen3.6-27B-Q4_K_M.gguf`
- Hugging Face draft model: https://huggingface.co/Lucebox/Qwen3.6-27B-DFlash-GGUF
- Draft file: `dflash-draft-3.6-q4_k_m.gguf`
- License: Apache 2.0

The RTX 3090 has 24 GB VRAM, so this profile lets Lucebox own the card while active and starts with
a `32768` token context, `tq3_0` KV, DDTree budget `22`, and `--lazy-draft`. OpenCode talks to an
autowake proxy on `127.0.0.1:18080`; the real Lucebox backend binds to `127.0.0.1:18081` and is
stopped after 1 hour without API traffic.

## Components

- Profile variables: `config/profile-96gb-ubuntu-nvidia.env`
- OpenCode config: `config/opencode-96gb-ubuntu-nvidia.json`
- LM Studio model metadata: `config/lmstudio-models/unsloth/qwen3.6-27b`
- Linux install helper: `scripts/install-opencode-config-linux.sh`
- Lucebox model/build helper: `scripts/ensure-lucebox-linux.sh`
- Lucebox service helper: `scripts/install-lucebox-service-linux.sh`
- Lucebox autowake proxy: `scripts/lucebox-autowake-proxy.py`
- LM Studio embedding helper: `scripts/ensure-lmstudio-models-linux.sh`
- Qwen instruction prelude: `~/.config/opencode/qwen36-instructions.md`
- Local workflow instruction: `~/.config/opencode/local-coding-workflow.md`
- Main chat model: `lucebox/luce-dflash`
- Rollback chat model: `Qwen3.6-27B-UD-Q5_K_XL.gguf`, wrapped locally as `unsloth/qwen3.6-27b`
- Main runtime: Lucebox DFlash C++/CUDA on NVIDIA
- Context: `32768`
- Output: `4096`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`, loaded through LM Studio with `--gpu off`
- Lucebox API: `http://127.0.0.1:18080/v1` through the autowake proxy
- Lucebox backend API: `http://127.0.0.1:18081/v1`
- LM Studio embedding API: `http://127.0.0.1:1234/v1`
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

LM Studio's CLI ships with the app. This profile uses the direct Hugging Face file URL plus a local
model.yaml wrapper so Qwen's `enable_thinking` template variable defaults off for OpenCode.

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

Build Lucebox and download the target/draft pair:

```bash
export OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env"
scripts/ensure-lucebox-linux.sh
scripts/install-opencode-config-linux.sh
scripts/install-lucebox-service-linux.sh
```

Ensure LM Studio runs the embedding model only:

```bash
lms server start
scripts/ensure-lmstudio-models-linux.sh
```

Normal mode unloads `local-coder` if it is loaded, then loads:

```bash
lms load text-embedding-nomic-embed-text-v1.5 \
  --identifier text-embedding-nomic-embed-text-v1.5 \
  --gpu off \
  --ttl 3600
```

If the embedding model expires while OpenCode is running, `local_code_index` invokes the installed
LM Studio ensure script once and retries the embedding request.

For rollback testing only:

```bash
LMSTUDIO_LOAD_CHAT_ROLLBACK=1 scripts/ensure-lmstudio-models-linux.sh
```

Watch VRAM during first Lucebox load and first request:

```bash
nvidia-smi
```

The proxy service stays enabled at login, while `lucebox-dflash.service` is left disabled and starts
only when the proxy receives `/v1/*` or `/props` traffic. `GET /health` checks proxy/backend status
without waking the model.

## Validate

Static validation:

```bash
jq . config/opencode-96gb-ubuntu-nvidia.json >/dev/null
OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
  OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
  scripts/validate-profile-sync.sh
zsh -n scripts/*.sh scripts/lib/profile.sh
SMOKE_SKIP_HARDWARE=1 SMOKE_SKIP_LMSTUDIO=1 SMOKE_SKIP_LUCEBOX=1 SMOKE_SKIP_LAUNCHCTL=1 \
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
- Lucebox proxy responds on `127.0.0.1:18080`.
- Lucebox backend wakes on demand at `127.0.0.1:18081` and releases VRAM after idle unload.
- LM Studio has only the embedding model loaded in normal mode.
- LM Studio listens only on `127.0.0.1:1234`.
- Lucebox generation returns `OK lucebox`.
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
