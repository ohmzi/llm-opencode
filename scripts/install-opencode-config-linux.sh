#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PROFILE="${OPENCODE_BACKUP_PROFILE:-$ROOT/config/profile-96gb-ubuntu-nvidia.env}"
export OPENCODE_BACKUP_PROFILE="$PROFILE"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars OPENCODE_CONFIG_DIR OPENCODE_LAUNCH_ENV TARGET_HOME

CONFIG="${OPENCODE_BACKUP_CONFIG:-config/opencode-96gb-ubuntu-nvidia.json}"
if [[ "$CONFIG" != /* ]]; then
  CONFIG="$ROOT/$CONFIG"
fi

DEST="$OPENCODE_CONFIG_DIR"
STAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$DEST/mcp" "$DEST/lib"

if [[ -f "$DEST/opencode.json" ]]; then
  cp "$DEST/opencode.json" "$DEST/opencode.json.bak-$STAMP"
fi

cp "$CONFIG" "$DEST/opencode.json"
cp "$LLM_OPENCODE_PROFILE" "$DEST/profile.env"
cp "$ROOT/config/profile-96gb-ubuntu-nvidia.env" "$DEST/profile-96gb-ubuntu-nvidia.env"
cp "$ROOT/config/profile-48gb.env" "$DEST/profile-48gb.env"
cp "$ROOT/config/profile-24gb.env" "$DEST/profile-24gb.env"
cp "$ROOT/config/qwen36-instructions.md" "$DEST/qwen36-instructions.md"
cp "$ROOT/config/local-coding-workflow.md" "$DEST/local-coding-workflow.md"
cp "$ROOT/mcp/local_code_index.py" "$DEST/mcp/local_code_index.py"
cp "$ROOT/mcp/local_dev_tools.py" "$DEST/mcp/local_dev_tools.py"
cp "$ROOT/mcp/remote_mcp_proxy.py" "$DEST/mcp/remote_mcp_proxy.py"
cp "$ROOT/scripts/lib/profile.sh" "$DEST/lib/profile.sh"
cp "$ROOT/config/opencode-launch-env-linux.sh" "$OPENCODE_LAUNCH_ENV"
cp "$ROOT/scripts/ensure-lmstudio-models-linux.sh" "$DEST/ensure-lmstudio-models-linux.sh"
cp "$ROOT/scripts/ensure-lucebox-linux.sh" "$DEST/ensure-lucebox-linux.sh"
cp "$ROOT/scripts/start-lucebox-dflash.sh" "$DEST/start-lucebox-dflash.sh"
cp "$ROOT/scripts/lucebox-autowake-proxy.py" "$DEST/lucebox-autowake-proxy.py"
cp "$ROOT/scripts/install-lucebox-service-linux.sh" "$DEST/install-lucebox-service-linux.sh"
cp "$ROOT/scripts/check-model-state.sh" "$DEST/check-model-state.sh"
cp "$ROOT/scripts/validate-profile-sync.sh" "$DEST/validate-profile-sync.sh"

MODEL_METADATA_SOURCE="$ROOT/config/lmstudio-models"
MODEL_METADATA_DEST="$TARGET_HOME/.lmstudio/hub/models"
if [[ -d "$MODEL_METADATA_SOURCE" ]]; then
  mkdir -p "$MODEL_METADATA_DEST"
  cp -R "$MODEL_METADATA_SOURCE/"* "$MODEL_METADATA_DEST/"
fi

chmod +x "$DEST/mcp/"*.py "$DEST/ensure-lmstudio-models-linux.sh" "$DEST/ensure-lucebox-linux.sh" "$DEST/start-lucebox-dflash.sh" "$DEST/lucebox-autowake-proxy.py" "$DEST/install-lucebox-service-linux.sh" "$DEST/check-model-state.sh" "$DEST/validate-profile-sync.sh" "$OPENCODE_LAUNCH_ENV"
jq . "$DEST/opencode.json" >/dev/null

echo "Installed OpenCode Ubuntu NVIDIA config into $DEST"
echo "Previous config backup, if any: $DEST/opencode.json.bak-$STAMP"
echo "For GUI launches, export OPENCODE_ENABLE_EXA=1 and OPENCODE_EXPERIMENTAL_LSP_TOOL=true in your desktop environment."
