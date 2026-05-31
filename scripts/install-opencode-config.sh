#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars OPENCODE_CONFIG_DIR

DEST="$OPENCODE_CONFIG_DIR"
STAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$DEST/mcp" "$DEST/instructions" "$DEST/lib"

if [[ -f "$DEST/opencode.json" ]]; then
  cp "$DEST/opencode.json" "$DEST/opencode.json.bak-$STAMP"
fi

cp "$ROOT/config/opencode.json" "$DEST/opencode.json"
cp "$ROOT/config/profile-24gb.env" "$DEST/profile-24gb.env"
cp "$ROOT/config/instructions/local-coding-workflow.md" "$DEST/instructions/local-coding-workflow.md"
cp "$ROOT/mcp/local_code_index.py" "$DEST/mcp/local_code_index.py"
cp "$ROOT/mcp/local_dev_tools.py" "$DEST/mcp/local_dev_tools.py"
cp "$ROOT/mcp/remote_mcp_proxy.py" "$DEST/mcp/remote_mcp_proxy.py"
cp "$ROOT/scripts/lib/profile.sh" "$DEST/lib/profile.sh"
cp "$ROOT/scripts/ensure-lmstudio-models.sh" "$DEST/ensure-lmstudio-models.sh"
cp "$ROOT/scripts/repair-lmstudio-mlx-runtime.sh" "$DEST/repair-lmstudio-mlx-runtime.sh"
cp "$ROOT/scripts/check-model-state.sh" "$DEST/check-model-state.sh"
cp "$ROOT/scripts/validate-profile-sync.sh" "$DEST/validate-profile-sync.sh"

chmod +x "$DEST/mcp/"*.py "$DEST/ensure-lmstudio-models.sh" "$DEST/repair-lmstudio-mlx-runtime.sh" "$DEST/check-model-state.sh" "$DEST/validate-profile-sync.sh"
jq . "$DEST/opencode.json" >/dev/null

echo "Installed OpenCode 24 GB config into $DEST"
echo "Previous config backup, if any: $DEST/opencode.json.bak-$STAMP"
