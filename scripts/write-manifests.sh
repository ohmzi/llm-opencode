#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars LMS PROFILE_NAME PROFILE_SLUG TARGET_USER TARGET_HOME MIN_MEM_BYTES MAX_MEM_BYTES LMSTUDIO_BASE_URL CHAT_ID CHAT_GET_REF CHAT_MODEL_KEY CHAT_MODEL_PATH CHAT_MODEL_FORMAT CHAT_MODEL_QUANTIZATION CHAT_CONTEXT CHAT_OUTPUT FAST_ID FAST_GET_REF FAST_MODEL_KEY FAST_MODEL_PATH FAST_MODEL_FORMAT FAST_MODEL_QUANTIZATION FAST_CONTEXT FAST_OUTPUT EMBED_ID EMBED_MODEL_KEY EMBED_MODEL_PATH EMBED_DIMENSIONS OPENCODE_CONFIG OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB OPENCODE_LAUNCH_ENV OPENCODE_LAUNCH_AGENT_PLIST OPENCODE_DEFAULT_AGENT OPENCODE_MODEL OPENCODE_CODER_MODEL

mkdir -p "$ROOT/manifests"

if [[ -x "$LMS" ]]; then
  "$LMS" ls --json > "$ROOT/manifests/models.json"
else
  printf '[]\n' > "$ROOT/manifests/models.json"
fi

jq -n \
  --arg profile "$PROFILE_NAME" \
  --arg chat_id "$CHAT_ID" \
  --arg chat_source "$CHAT_GET_REF" \
  --arg chat_key "$CHAT_MODEL_KEY" \
  --arg chat_path "$CHAT_MODEL_PATH" \
  --arg chat_format "$CHAT_MODEL_FORMAT" \
  --arg chat_quant "$CHAT_MODEL_QUANTIZATION" \
  --argjson chat_context "$CHAT_CONTEXT" \
  --argjson chat_output "$CHAT_OUTPUT" \
  --arg fast_id "$FAST_ID" \
  --arg fast_source "$FAST_GET_REF" \
  --arg fast_key "$FAST_MODEL_KEY" \
  --arg fast_path "$FAST_MODEL_PATH" \
  --arg fast_format "$FAST_MODEL_FORMAT" \
  --arg fast_quant "$FAST_MODEL_QUANTIZATION" \
  --argjson fast_context "$FAST_CONTEXT" \
  --argjson fast_output "$FAST_OUTPUT" \
  --arg embed_id "$EMBED_ID" \
  --arg embed_key "$EMBED_MODEL_KEY" \
  --arg embed_path "$EMBED_MODEL_PATH" \
  --argjson embed_dims "$EMBED_DIMENSIONS" \
  '{
    profile: $profile,
    models: [
      {
        role: "coding",
        identifier: $chat_id,
        source: $chat_source,
        modelKey: $chat_key,
        path: $chat_path,
        format: $chat_format,
        quantization: $chat_quant,
        context: $chat_context,
        output: $chat_output
      },
      {
        role: "fast-default",
        identifier: $fast_id,
        source: $fast_source,
        modelKey: $fast_key,
        path: $fast_path,
        format: $fast_format,
        quantization: $fast_quant,
        context: $fast_context,
        output: $fast_output
      },
      {
        role: "embedding",
        identifier: $embed_id,
        modelKey: $embed_key,
        path: $embed_path,
        dimensions: $embed_dims
      }
    ]
  }' > "$ROOT/manifests/expected-models-${PROFILE_SLUG}.json"

export PROFILE_NAME PROFILE_SLUG TARGET_USER TARGET_HOME MIN_MEM_BYTES MAX_MEM_BYTES LMS LMSTUDIO_BASE_URL LMSTUDIO_HOST LMSTUDIO_PORT CHAT_ID CHAT_GET_REF CHAT_MODEL_PATH CHAT_MODEL_FORMAT CHAT_MODEL_QUANTIZATION CHAT_CONTEXT CHAT_OUTPUT FAST_ID FAST_GET_REF FAST_MODEL_PATH FAST_MODEL_FORMAT FAST_MODEL_QUANTIZATION FAST_CONTEXT FAST_OUTPUT EMBED_ID OPENCODE_CONFIG OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB OPENCODE_LAUNCH_ENV OPENCODE_LAUNCH_AGENT_PLIST OPENCODE_DEFAULT_AGENT OPENCODE_MODEL OPENCODE_CODER_MODEL LLM_OPENCODE_PROFILE

python3 - <<'PY' > "$ROOT/manifests/system-${PROFILE_SLUG}.json"
import json, os, platform, subprocess

LMS = os.environ["LMS"]

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True).strip()
    except Exception:
        return None

data = {
    "profile": os.environ["PROFILE_NAME"],
    "profile_file": os.environ.get("LLM_OPENCODE_PROFILE"),
    "target_user": os.environ["TARGET_USER"],
    "target_home": os.environ["TARGET_HOME"],
    "expected_memory_bytes": {
        "min": int(os.environ["MIN_MEM_BYTES"]),
        "max": int(os.environ["MAX_MEM_BYTES"]),
    },
    "home": os.path.expanduser("~"),
    "arch": run(["uname", "-m"]),
    "hw_memsize_bytes": int(run(["sysctl", "-n", "hw.memsize"]) or 0),
    "macos": {
        "ProductName": run(["sw_vers", "-productName"]),
        "ProductVersion": run(["sw_vers", "-productVersion"]),
        "BuildVersion": run(["sw_vers", "-buildVersion"]),
    },
    "apps": {
        "lm_studio": run(["defaults", "read", "/Applications/LM Studio.app/Contents/Info", "CFBundleShortVersionString"]),
        "opencode": run(["defaults", "read", "/Applications/OpenCode.app/Contents/Info", "CFBundleShortVersionString"]),
    },
    "lmstudio": {
        "server": os.environ["LMSTUDIO_BASE_URL"],
        "host": os.environ.get("LMSTUDIO_HOST"),
        "port": os.environ.get("LMSTUDIO_PORT"),
        "chat_model": os.environ["CHAT_ID"],
        "chat_model_source": os.environ.get("CHAT_GET_REF"),
        "chat_model_path": os.environ["CHAT_MODEL_PATH"],
        "chat_model_format": os.environ["CHAT_MODEL_FORMAT"],
        "chat_model_quantization": os.environ["CHAT_MODEL_QUANTIZATION"],
        "chat_context": int(os.environ["CHAT_CONTEXT"]),
        "chat_output": int(os.environ["CHAT_OUTPUT"]),
        "fast_model": os.environ["FAST_ID"],
        "fast_model_source": os.environ.get("FAST_GET_REF"),
        "fast_model_path": os.environ["FAST_MODEL_PATH"],
        "fast_model_format": os.environ["FAST_MODEL_FORMAT"],
        "fast_model_quantization": os.environ["FAST_MODEL_QUANTIZATION"],
        "fast_context": int(os.environ["FAST_CONTEXT"]),
        "fast_output": int(os.environ["FAST_OUTPUT"]),
        "embedding_model": os.environ["EMBED_ID"],
        "runtime_ls": run([LMS, "runtime", "ls"]),
    },
    "opencode": {
        "config": os.environ["OPENCODE_CONFIG"],
        "desktop_state": os.environ["OPENCODE_DESKTOP_STATE"],
        "index_db": os.environ["OPENCODE_INDEX_DB"],
        "launch_env": os.environ["OPENCODE_LAUNCH_ENV"],
        "launch_agent": os.environ["OPENCODE_LAUNCH_AGENT_PLIST"],
        "default_agent": os.environ["OPENCODE_DEFAULT_AGENT"],
        "default_model": os.environ["OPENCODE_MODEL"],
        "coding_model": os.environ["OPENCODE_CODER_MODEL"],
        "mcp": ["local_code_index", "local_dev_tools", "context7", "gh_grep"],
        "agents": ["fast", "explain", "indexer", "build", "plan", "codebase-researcher", "debugger", "test-runner", "code-reviewer", "doc-researcher", "security-auditor"],
        "commands": ["/explain", "/research", "/debug", "/test", "/review", "/docs", "/security", "/index", "/implement"],
        "lsp": ["typescript", "eslint"],
    },
}
print(json.dumps(data, indent=2))
PY

echo "Wrote manifests into $ROOT/manifests"
