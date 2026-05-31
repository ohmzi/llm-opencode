#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars OPENCODE_CONFIG_DIR OPENCODE_CONFIG OPENCODE_MODEL

mkdir -p "$ROOT/config/instructions" "$ROOT/mcp" "$ROOT/manifests" "$ROOT/scripts/lib"

live_model="$(jq -r '.model // ""' "$OPENCODE_CONFIG" 2>/dev/null || true)"
if [[ "$live_model" != "$OPENCODE_MODEL" && "${BACKUP_ALLOW_PROFILE_MISMATCH:-0}" != "1" ]]; then
  echo "Refusing to back up live OpenCode config for model '$live_model' into active profile '$OPENCODE_MODEL'." >&2
  echo "Run install-opencode-config.sh on the target machine first, or set BACKUP_ALLOW_PROFILE_MISMATCH=1 intentionally." >&2
  exit 1
fi

cp "$OPENCODE_CONFIG" "$ROOT/config/opencode.json"
if [[ -f "$OPENCODE_CONFIG_DIR/qwen36-instructions.md" ]]; then
  cp "$OPENCODE_CONFIG_DIR/qwen36-instructions.md" "$ROOT/config/qwen36-instructions.md"
fi
if [[ -f "$OPENCODE_CONFIG_DIR/local-coding-workflow.md" ]]; then
  cp "$OPENCODE_CONFIG_DIR/local-coding-workflow.md" "$ROOT/config/local-coding-workflow.md"
elif [[ -f "$OPENCODE_CONFIG_DIR/instructions/local-coding-workflow.md" ]]; then
  cp "$OPENCODE_CONFIG_DIR/instructions/local-coding-workflow.md" "$ROOT/config/local-coding-workflow.md"
fi
cp "$OPENCODE_CONFIG_DIR/mcp/local_code_index.py" "$ROOT/mcp/local_code_index.py"
cp "$OPENCODE_CONFIG_DIR/mcp/local_dev_tools.py" "$ROOT/mcp/local_dev_tools.py"
if [[ -f "$OPENCODE_CONFIG_DIR/mcp/remote_mcp_proxy.py" ]]; then
  cp "$OPENCODE_CONFIG_DIR/mcp/remote_mcp_proxy.py" "$ROOT/mcp/remote_mcp_proxy.py"
fi

if [[ -f "$OPENCODE_CONFIG_DIR/profile.env" ]]; then
  cp "$OPENCODE_CONFIG_DIR/profile.env" "$ROOT/config/profile-48gb.env"
elif [[ -f "$OPENCODE_CONFIG_DIR/profile-48gb.env" ]]; then
  cp "$OPENCODE_CONFIG_DIR/profile-48gb.env" "$ROOT/config/profile-48gb.env"
fi
if [[ -f "$OPENCODE_CONFIG_DIR/lib/profile.sh" ]]; then
  cp "$OPENCODE_CONFIG_DIR/lib/profile.sh" "$ROOT/scripts/lib/profile.sh"
fi
if [[ "${BACKUP_LIVE_HELPERS:-0}" == "1" && -f "$OPENCODE_CONFIG_DIR/ensure-lmstudio-models.sh" ]]; then
  cp "$OPENCODE_CONFIG_DIR/ensure-lmstudio-models.sh" "$ROOT/scripts/ensure-lmstudio-models.sh"
fi
if [[ "${BACKUP_LIVE_HELPERS:-0}" == "1" && -f "$OPENCODE_CONFIG_DIR/repair-lmstudio-mlx-runtime.sh" ]]; then
  cp "$OPENCODE_CONFIG_DIR/repair-lmstudio-mlx-runtime.sh" "$ROOT/scripts/repair-lmstudio-mlx-runtime.sh"
fi

chmod +x "$ROOT/mcp/"*.py "$ROOT/scripts/"*.sh
jq . "$ROOT/config/opencode.json" >/dev/null
"$ROOT/scripts/validate-profile-sync.sh"

"$ROOT/scripts/check-model-state.sh" || true
"$ROOT/scripts/write-manifests.sh"

echo "Backed up current OpenCode/LM Studio setup into $ROOT"
