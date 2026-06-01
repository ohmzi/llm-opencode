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
a `49152` token context, `2048` output cap, `tq3_0` KV, DDTree budget `22`, `--lazy-draft`,
and prefix cache disabled with `--prefix-cache-slots 0` to avoid stale snapshot restore failures.
OpenCode talks to an
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
- Context: `49152`
- Output: `2048`
- Prefix cache slots: `0`
- Embedding model: `text-embedding-nomic-embed-text-v1.5`, loaded through LM Studio with `--gpu off`
- Lucebox API: `http://127.0.0.1:18080/v1` through the autowake proxy
- Lucebox backend API: `http://127.0.0.1:18081/v1`
- LM Studio embedding API: `http://127.0.0.1:1234/v1`
- Local index DB: `~/.cache/opencode/local-code-index.sqlite3`

## Ubuntu Prerequisites

Install the normal local development tooling:

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake curl git git-lfs jq lsof nodejs npm pkg-config \
  python3 python3-pip python3-venv ripgrep zsh
python3 -m pip install --user 'huggingface_hub[cli]'
git lfs install
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

Lucebox must already be cloned at `LUCEBOX_HOME`, currently:

```bash
/home/ohmz/StudioProjects/lucebox-hub
```

Model weights stay in the Lucebox and LM Studio model directories. Do not copy `.gguf`,
`.safetensors`, `.bin`, `.ckpt`, or other weight files into this backup repository.

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

After install, expected service state is:

```bash
systemctl --user is-active lucebox-dflash-proxy.service
systemctl --user is-active lucebox-dflash.service || true
curl -sS http://127.0.0.1:18080/health | jq .
```

The proxy should be `active`; the backend can be `inactive` until the first `/v1/*` or `/props`
request wakes it.

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
without waking the model. The proxy also clamps oversized chat completion requests to the configured
output cap before forwarding them to Lucebox.

Current stability choices:

- `LUCEBOX_CONTEXT=49152`: avoids the earlier `prompt + max_tokens exceeds context window` failure
  when OpenCode sends a large tool/MCP prompt.
- `LUCEBOX_OUTPUT=2048`: leaves more room for the prompt on a 24 GB RTX 3090 and keeps runaway
  completion budgets from exceeding the context window.
- `LUCEBOX_PROXY_MAX_TOKENS=$LUCEBOX_OUTPUT`: clamps incoming `/v1/chat/completions` request budgets
  before Lucebox sees them.
- `LUCEBOX_PREFIX_CACHE_SLOTS=0`: disables Lucebox prefix-cache restores after repeated
  `snapshot_longer_than_prompt` failures that made OpenCode appear stuck with no tokens flowing.
- `LUCEBOX_IDLE_UNLOAD_SECONDS=3600`: unloads the backend after 1 hour without proxied API traffic.

The `--lazy-draft ignored` line can appear in Lucebox logs with this build. It is not treated as a
smoke-test failure as long as chat completions succeed and logs show `error=-`.

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

Direct Lucebox and OpenCode checks:

```bash
curl -sS --max-time 900 http://127.0.0.1:18080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"luce-dflash","temperature":0,"max_tokens":16,"messages":[{"role":"user","content":"Reply exactly: OK lucebox"}]}' \
  | jq -r '.choices[0].message.content // .error.message // .'

opencode run --model lucebox/luce-dflash --format json 'Reply exactly: OK opencode'
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
- Lucebox backend logs show `prefix_cache = 0 slots`.
- Recent Lucebox completions finish with `ok=true` and `error=-`.
- Local MCPs list expected tools and `local_dev_tools` blocks destructive commands.
- Remote MCP endpoints respond.
- OpenCode config contains the expected four MCPs, eight agents, eight commands, and two LSP
  entries.

## Troubleshooting

### OpenCode says `prompt + max_tokens exceeds context window`

This was caused by a large OpenCode prompt plus a `4096` completion budget on a `32768` context. The
Ubuntu profile now uses `49152` context, `2048` output, and a proxy clamp for incoming chat budgets.

Check and repair:

```bash
rg -n '"context"|"output"|LUCEBOX_CONTEXT|LUCEBOX_OUTPUT|LUCEBOX_PROXY_MAX_TOKENS' \
  config/profile-96gb-ubuntu-nvidia.env config/opencode-96gb-ubuntu-nvidia.json
scripts/install-opencode-config-linux.sh
scripts/install-lucebox-service-linux.sh
```

If the TUI already hit the error, cancel that OpenCode request with `Ctrl+C` or restart OpenCode.

### OpenCode looks stuck and GPU usage drops

Check Lucebox logs:

```bash
journalctl --user -u lucebox-dflash.service --since '20 minutes ago' --no-pager \
  | rg 'snapshot_longer_than_prompt|chat DONE|prefix_cache|error='
```

If `snapshot_longer_than_prompt` appears, confirm the restarted backend uses prefix cache slots `0`:

```bash
ps -eo pid,args | rg 'dflash_server|prefix-cache-slots'
journalctl --user -u lucebox-dflash.service --since '5 minutes ago' --no-pager | rg 'prefix_cache'
```

Then reinstall/restart the service and retry the OpenCode prompt:

```bash
scripts/install-opencode-config-linux.sh
scripts/install-lucebox-service-linux.sh
```

### First request after idle takes a while

This is expected. The proxy is always on at `127.0.0.1:18080`, but the real Lucebox backend at
`127.0.0.1:18081` is stopped after 1 hour idle. The first `/v1/*` request wakes the service, loads
the model into VRAM, waits for backend health, and then forwards the original request.

`GET /health` reports status without waking the model. `GET /props` wakes the model because it needs
backend properties.

### LM Studio competes with Lucebox for VRAM

Normal mode should keep only the embedding model loaded in LM Studio:

```bash
lms ps
scripts/ensure-lmstudio-models-linux.sh
```

The ensure script unloads `local-coder` in normal mode and loads
`text-embedding-nomic-embed-text-v1.5` with `--gpu off --ttl 3600`. To explicitly test rollback chat:

```bash
LMSTUDIO_LOAD_CHAT_ROLLBACK=1 scripts/ensure-lmstudio-models-linux.sh
```

Unload rollback before returning to Lucebox mode:

```bash
scripts/ensure-lmstudio-models-linux.sh
```

### Local code indexing uses too much CPU

Keep background indexing enabled by default:

```bash
OPENCODE_INDEX_BACKGROUND=1
OPENCODE_INDEX_BACKGROUND_SECONDS=300
OPENCODE_INDEX_AUTO_SYNC_SECONDS=300
```

If CPU noise is annoying, set `OPENCODE_INDEX_BACKGROUND=0` in
`config/profile-96gb-ubuntu-nvidia.env`, or increase the two interval values, then reinstall the
OpenCode config.

### Shell warning about `ohmzai`

If every shell command prints:

```text
/bin/bash: ohmzai: line 1: syntax error: unexpected end of file
/bin/bash: error importing function definition for `ohmzai'
```

that is an unrelated exported shell function/startup environment issue. It is noisy but did not
prevent Lucebox, LM Studio embeddings, MCPs, or OpenCode smoke tests from passing.

## Keep The Baseline

Do not replace `config/profile-48gb.env` or `config/opencode.json` with this Linux profile unless
you intentionally want to change the default Mac backup. The Ubuntu setup is selected with:

```bash
OPENCODE_BACKUP_PROFILE=config/profile-96gb-ubuntu-nvidia.env
OPENCODE_BACKUP_CONFIG=config/opencode-96gb-ubuntu-nvidia.json
```

Do not copy `.gguf` model weights into this repository. Store only model identifiers, URLs,
checksums, profile variables, scripts, and docs.
