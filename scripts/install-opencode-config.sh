#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars OPENCODE_CONFIG_DIR OPENCODE_LAUNCH_ENV OPENCODE_LAUNCH_AGENT_PLIST

DEST="$OPENCODE_CONFIG_DIR"
STAMP="$(date +%Y%m%d%H%M%S)"

mkdir -p "$DEST/mcp" "$DEST/lib" "$(dirname "$OPENCODE_LAUNCH_AGENT_PLIST")"

if [[ -f "$DEST/opencode.json" ]]; then
  cp "$DEST/opencode.json" "$DEST/opencode.json.bak-$STAMP"
fi

cp "$ROOT/config/opencode.json" "$DEST/opencode.json"
cp "$LLM_OPENCODE_PROFILE" "$DEST/profile.env"
cp "$ROOT/config/profile-48gb.env" "$DEST/profile-48gb.env"
cp "$ROOT/config/profile-24gb.env" "$DEST/profile-24gb.env"
cp "$ROOT/config/qwen36-instructions.md" "$DEST/qwen36-instructions.md"
cp "$ROOT/config/local-coding-workflow.md" "$DEST/local-coding-workflow.md"
cp "$ROOT/mcp/local_code_index.py" "$DEST/mcp/local_code_index.py"
cp "$ROOT/mcp/local_dev_tools.py" "$DEST/mcp/local_dev_tools.py"
cp "$ROOT/mcp/remote_mcp_proxy.py" "$DEST/mcp/remote_mcp_proxy.py"
cp "$ROOT/scripts/lib/profile.sh" "$DEST/lib/profile.sh"
cp "$ROOT/config/opencode-launch-env.sh" "$OPENCODE_LAUNCH_ENV"
OPENCODE_LAUNCH_AGENT_LABEL="${OPENCODE_LAUNCH_AGENT_LABEL:-com.ohmz.opencode.env}" OPENCODE_LAUNCH_ENV="$OPENCODE_LAUNCH_ENV" /usr/bin/python3 - <<'PY' > "$OPENCODE_LAUNCH_AGENT_PLIST"
import os
import plistlib
import sys

data = {
    "Label": os.environ["OPENCODE_LAUNCH_AGENT_LABEL"],
    "ProgramArguments": [os.environ["OPENCODE_LAUNCH_ENV"]],
    "RunAtLoad": True,
    "StandardOutPath": f"/tmp/{os.environ['OPENCODE_LAUNCH_AGENT_LABEL']}.out",
    "StandardErrorPath": f"/tmp/{os.environ['OPENCODE_LAUNCH_AGENT_LABEL']}.err",
}
plistlib.dump(data, sys.stdout.buffer, sort_keys=False)
PY
cp "$ROOT/scripts/ensure-lmstudio-models.sh" "$DEST/ensure-lmstudio-models.sh"
cp "$ROOT/scripts/repair-lmstudio-mlx-runtime.sh" "$DEST/repair-lmstudio-mlx-runtime.sh"
cp "$ROOT/scripts/check-model-state.sh" "$DEST/check-model-state.sh"
cp "$ROOT/scripts/validate-profile-sync.sh" "$DEST/validate-profile-sync.sh"

chmod +x "$DEST/mcp/"*.py "$DEST/ensure-lmstudio-models.sh" "$DEST/repair-lmstudio-mlx-runtime.sh" "$DEST/check-model-state.sh" "$DEST/validate-profile-sync.sh" "$OPENCODE_LAUNCH_ENV"
jq . "$DEST/opencode.json" >/dev/null
plutil -lint "$OPENCODE_LAUNCH_AGENT_PLIST" >/dev/null

launchctl setenv OPENCODE_ENABLE_EXA "${OPENCODE_ENABLE_EXA:-1}" || true
launchctl setenv OPENCODE_EXPERIMENTAL_LSP_TOOL "${OPENCODE_EXPERIMENTAL_LSP_TOOL:-true}" || true
launchctl bootout "gui/$(id -u)" "$OPENCODE_LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$OPENCODE_LAUNCH_AGENT_PLIST" >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/${OPENCODE_LAUNCH_AGENT_LABEL:-com.ohmz.opencode.env}" >/dev/null 2>&1 || true

echo "Installed OpenCode 48 GB config into $DEST"
echo "Previous config backup, if any: $DEST/opencode.json.bak-$STAMP"
echo "LaunchAgent staged at $OPENCODE_LAUNCH_AGENT_PLIST"
