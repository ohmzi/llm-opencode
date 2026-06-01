#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${SCRIPT_DIR:h}"
if [[ -f "$ROOT/scripts/lib/profile.sh" ]]; then
  source "$ROOT/scripts/lib/profile.sh"
elif [[ -f "$SCRIPT_DIR/lib/profile.sh" ]]; then
  source "$SCRIPT_DIR/lib/profile.sh"
else
  echo "Could not find scripts/lib/profile.sh" >&2
  exit 1
fi

require_profile_vars OPENCODE_CONFIG_DIR LUCEBOX_SERVICE_NAME LUCEBOX_HOME LUCEBOX_HOST LUCEBOX_PORT

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/$LUCEBOX_SERVICE_NAME.service"
START_SCRIPT="$OPENCODE_CONFIG_DIR/start-lucebox-dflash.sh"

if [[ ! -x "$START_SCRIPT" ]]; then
  echo "Missing executable start script: $START_SCRIPT" >&2
  echo "Run install-opencode-config-linux.sh first." >&2
  exit 1
fi

mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Lucebox DFlash local OpenCode model server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$LUCEBOX_HOME
ExecStart=$START_SCRIPT
Restart=on-failure
RestartSec=5
TimeoutStartSec=900

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$LUCEBOX_SERVICE_NAME.service"

echo "Installed and started $LUCEBOX_SERVICE_NAME.service"
echo "Health: http://$LUCEBOX_HOST:$LUCEBOX_PORT/health"
