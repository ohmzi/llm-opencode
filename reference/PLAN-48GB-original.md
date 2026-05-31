# Reference Only: 48 GB macOS Plan

This file is preserved only as historical/reference material from `/Users/ohmz/Desktop/PLAN.md`.
It is not the active setup for this backup folder. The active profile is the 24 GB plan in `../PLAN-24GB.md`.

# 48 GB macOS Local Coding LLM Setup: Qwen3.6 MLX 8-bit + OpenCode Indexing

## Summary
Set up LM Studio and OpenCode Desktop on an Apple Silicon Mac with 48 GB RAM using one primary coding model:

`froggeric/qwen3.6-27b-mlx-8bit` loaded as `local-coder`.

Use this instead of Qwen3-Coder because the user wants a larger high-quality **MLX-native Qwen3.6** setup. This model is about `28 GB`, lists `35 GB` minimum system memory, includes fixed LM Studio tool-calling/developer-role template support, and should fit a 48 GB Mac with a 32K working context.

Sources:
- [LM Studio Qwen3.6 MLX 8-bit](https://lmstudio.ai/froggeric/qwen3.6-27b-mlx-8bit)
- [Hugging Face froggeric/Qwen3.6-27B-MLX-8bit](https://huggingface.co/froggeric/Qwen3.6-27B-MLX-8bit)
- [OpenCode config docs](https://dev.opencode.ai/docs/config)

## Key Changes
- Install official apps only:
  - LM Studio from `https://lmstudio.ai/download`
  - OpenCode Desktop from `https://opencode.ai/download`
  - Do not install Homebrew.

- Preflight:
  ```bash
  test "$(uname -m)" = "arm64"
  sysctl -n hw.memsize
  ```

- Download and load Qwen3.6 MLX 8-bit:
  ```bash
  lms get froggeric/qwen3.6-27b-mlx-8bit --mlx --yes

  MODEL_KEY="$(lms ls --json | jq -r '.[] | select(.path=="froggeric/Qwen3.6-27B-MLX-8bit" or .indexedModelIdentifier=="froggeric/Qwen3.6-27B-MLX-8bit").modelKey' | head -1)"
  test -n "$MODEL_KEY"

  lms unload --all || true
  lms load "$MODEL_KEY" \
    --identifier local-coder \
    --context-length 32768 \
    --gpu max \
    --parallel 1 \
    --ttl 3600 \
    --yes
  ```

- Keep LM Studio local-only:
  - Server: `127.0.0.1:1234`
  - No LAN exposure.

- Create `~/.config/opencode/qwen36-instructions.md`:
  ```md
  You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>

  Follow OpenCode's tool-use and coding instructions exactly. Keep tool calls valid, concise, and compatible with OpenAI-style tool calling.
  ```

- Create `~/.config/opencode/opencode.json`:
  ```json
  {
    "$schema": "https://opencode.ai/config.json",
    "enabled_providers": ["lmstudio"],
    "instructions": [
      "/Users/REPLACE_WITH_USER/.config/opencode/qwen36-instructions.md"
    ],
    "provider": {
      "lmstudio": {
        "npm": "@ai-sdk/openai-compatible",
        "name": "LM Studio (local)",
        "whitelist": ["local-coder"],
        "options": {
          "baseURL": "http://127.0.0.1:1234/v1",
          "apiKey": "lmstudio",
          "timeout": 900000,
          "chunkTimeout": 900000
        },
        "models": {
          "local-coder": {
            "name": "Qwen3.6 27B MLX 8-bit (local, 32K)",
            "tool_call": true,
            "limit": {
              "context": 32768,
              "output": 4096
            }
          }
        }
      }
    },
    "compaction": {
      "auto": true,
      "prune": true,
      "reserved": 10000
    },
    "model": "lmstudio/local-coder",
    "small_model": "lmstudio/local-coder"
  }
  ```

## Code Indexing
- Add a local MCP server at `~/.config/opencode/mcp/local_code_index.py`.
- It must:
  - Expose `code_index_status`, `code_index_refresh`, and `code_index_search`.
  - Store chunks and embeddings in SQLite at `~/.cache/opencode/local-code-index.sqlite3`.
  - Use LM Studio embeddings via `http://127.0.0.1:1234/v1/embeddings`.
  - Use `text-embedding-nomic-embed-text-v1.5`.
  - Auto-discover current and future OpenCode Desktop projects from `~/Library/Application Support/ai.opencode.desktop/opencode.global.dat`.
  - Refresh in the background every `300` seconds.
  - Refresh opportunistically before search if the last sync is stale.
  - Remove stale indexed roots when projects disappear from OpenCode.
  - Ignore `.git`, `node_modules`, `build`, `dist`, `.gradle`, `DerivedData`, `Pods`, `.venv`, `target`, `.cache`, and large/binary files.
  - Index common code/document text files including Swift, Kotlin, Java, JS/TS, Python, JSON, Markdown, XML, YAML, Gradle, plist, shell, SQL, and README/Makefile-style files.

- Add this `mcp` section to `opencode.json` after the LLM smoke test passes:
  ```json
  {
    "mcp": {
      "local_code_index": {
        "type": "local",
        "command": [
          "/usr/bin/python3",
          "/Users/REPLACE_WITH_USER/.config/opencode/mcp/local_code_index.py"
        ],
        "environment": {
          "OPENCODE_INDEX_ROOTS": "auto",
          "OPENCODE_INDEX_AUTODISCOVER": "1",
          "OPENCODE_DESKTOP_STATE": "/Users/REPLACE_WITH_USER/Library/Application Support/ai.opencode.desktop/opencode.global.dat",
          "OPENCODE_INDEX_BACKGROUND": "1",
          "OPENCODE_INDEX_BACKGROUND_SECONDS": "300",
          "OPENCODE_INDEX_DB": "/Users/REPLACE_WITH_USER/.cache/opencode/local-code-index.sqlite3",
          "LMSTUDIO_EMBEDDING_URL": "http://127.0.0.1:1234/v1/embeddings",
          "LMSTUDIO_EMBEDDING_MODEL": "text-embedding-nomic-embed-text-v1.5"
        },
        "enabled": true,
        "timeout": 600000
      }
    }
  }
  ```

## Test Plan
- Validate config:
  ```bash
  jq . ~/.config/opencode/opencode.json >/dev/null
  ```

- Verify LM Studio and local binding:
  ```bash
  lms status
  lms ps
  curl -s http://127.0.0.1:1234/v1/models | jq -r '.data[].id'
  lsof -nP -iTCP:1234 -sTCP:LISTEN
  ```
  Expected listener: `127.0.0.1:1234`, not `0.0.0.0:1234`.

- Smoke test normal generation:
  ```bash
  curl -s http://127.0.0.1:1234/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "local-coder",
      "messages": [{"role": "user", "content": "No tools. Reply with OK local-coder."}],
      "max_tokens": 64,
      "temperature": 0
    }' | jq -r '.choices[0].message.content'
  ```

- Smoke test OpenCode-compaction-style prompt rendering:
  ```bash
  curl -s http://127.0.0.1:1234/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d '{
      "model": "local-coder",
      "messages": [{"role": "user", "content": "<tool_response>\ncompact summary payload\n</tool_response>"}],
      "max_tokens": 64,
      "temperature": 0
    }' | jq .
  ```
  Expected: no Jinja/template error.

- OpenCode Desktop smoke test:
  - Select `LM Studio (local) / Qwen3.6 27B MLX 8-bit (local, 32K)`.
  - Prompt: `No tools. Reply with OK and the model id you are using.`
  - Prompt: `No tools yet. Make a short plan for adding a simple UIAlertController on iOS app startup. Keep it under 5 bullets.`
  - Run `code_index_status`, then `code_index_refresh`, then `code_index_search` for a known symbol in an added project.

## Assumptions
- Target Mac is Apple Silicon with 48 GB unified memory.
- Use one visible OpenCode model only: `lmstudio/local-coder`.
- Prefer MLX 8-bit over q10/BF16; q10 is not a practical/common LM Studio MLX target, and BF16 is too large for comfortable 48 GB use.
- Do not install Qwen3-Coder, GGUF Qwen3.6, MTPLX, or extra fallback models during initial setup.
- If 32K context is unstable, reload the same model alias at `24576`, then `16384`; keep the OpenCode model id as `local-coder`.
- If the 8-bit model cannot load even at 16K, replace it with the same publisher’s 4-bit MLX model rather than adding a second visible model.
