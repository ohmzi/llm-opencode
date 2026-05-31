#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars LMS PROFILE_NAME TARGET_USER TARGET_HOME LMSTUDIO_BASE_URL CHAT_ID CHAT_MODEL_PATH CHAT_MODEL_FORMAT CHAT_MODEL_QUANTIZATION CHAT_CONTEXT CHAT_OUTPUT EMBED_ID OPENCODE_CONFIG OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB SOURCEKIT_LSP DEVELOPER_DIR

mkdir -p "$ROOT/manifests"

if [[ -x "$LMS" ]]; then
  "$LMS" ls --json > "$ROOT/manifests/models.json"
else
  printf '[]\n' > "$ROOT/manifests/models.json"
fi

export PROFILE_NAME TARGET_USER TARGET_HOME LMS LMSTUDIO_BASE_URL LMSTUDIO_HOST LMSTUDIO_PORT CHAT_ID CHAT_MODEL_PATH CHAT_MODEL_FORMAT CHAT_MODEL_QUANTIZATION CHAT_CONTEXT CHAT_OUTPUT EMBED_ID OPENCODE_CONFIG OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB SOURCEKIT_LSP DEVELOPER_DIR TOOLCHAINS LLM_OPENCODE_PROFILE

python3 - <<'PY' > "$ROOT/manifests/system-24gb.json"
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
        "chat_model_path": os.environ["CHAT_MODEL_PATH"],
        "chat_model_format": os.environ["CHAT_MODEL_FORMAT"],
        "chat_model_quantization": os.environ["CHAT_MODEL_QUANTIZATION"],
        "chat_context": int(os.environ["CHAT_CONTEXT"]),
        "chat_output": int(os.environ["CHAT_OUTPUT"]),
        "embedding_model": os.environ["EMBED_ID"],
        "runtime_ls": run([LMS, "runtime", "ls"]),
    },
    "opencode": {
        "config": os.environ["OPENCODE_CONFIG"],
        "desktop_state": os.environ["OPENCODE_DESKTOP_STATE"],
        "index_db": os.environ["OPENCODE_INDEX_DB"],
        "mcp": ["local_code_index", "local_dev_tools", "context7", "gh_grep"],
        "agents": ["build", "plan", "debug", "review"],
        "commands": ["/index", "/reindex", "/search-index", "/debug", "/review", "/docs"],
        "lsp": [{"name": "sourcekit-lsp", "command": os.environ["SOURCEKIT_LSP"], "developer_dir": os.environ["DEVELOPER_DIR"], "toolchains": os.environ.get("TOOLCHAINS")}],
    },
}
print(json.dumps(data, indent=2))
PY

echo "Wrote manifests into $ROOT/manifests"
