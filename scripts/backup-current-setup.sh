#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars OPENCODE_CONFIG_DIR OPENCODE_CONFIG

mkdir -p "$ROOT/config/instructions" "$ROOT/mcp" "$ROOT/manifests" "$ROOT/scripts/lib"

cp "$OPENCODE_CONFIG" "$ROOT/config/opencode.json"
cp "$OPENCODE_CONFIG_DIR/instructions/local-coding-workflow.md" "$ROOT/config/instructions/local-coding-workflow.md"
cp "$OPENCODE_CONFIG_DIR/mcp/local_code_index.py" "$ROOT/mcp/local_code_index.py"
cp "$OPENCODE_CONFIG_DIR/mcp/local_dev_tools.py" "$ROOT/mcp/local_dev_tools.py"
cp "$OPENCODE_CONFIG_DIR/mcp/remote_mcp_proxy.py" "$ROOT/mcp/remote_mcp_proxy.py"

if [[ -f "$OPENCODE_CONFIG_DIR/profile-24gb.env" ]]; then
  cp "$OPENCODE_CONFIG_DIR/profile-24gb.env" "$ROOT/config/profile-24gb.env"
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
