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

require_profile_vars OPENCODE_CONFIG_DIR LUCEBOX_SERVICE_NAME LUCEBOX_PROXY_SERVICE_NAME LUCEBOX_HOME LUCEBOX_HOST LUCEBOX_PORT LUCEBOX_PROXY_HOST LUCEBOX_PROXY_PORT LUCEBOX_BACKEND_URL LUCEBOX_BACKEND_HEALTH_URL LUCEBOX_IDLE_UNLOAD_SECONDS LUCEBOX_START_TIMEOUT_SECONDS LUCEBOX_PROXY_REQUEST_TIMEOUT_SECONDS LUCEBOX_IDLE_POLL_SECONDS

SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/$LUCEBOX_SERVICE_NAME.service"
PROXY_SERVICE_FILE="$SERVICE_DIR/$LUCEBOX_PROXY_SERVICE_NAME.service"
START_SCRIPT="$OPENCODE_CONFIG_DIR/start-lucebox-dflash.sh"
PROXY_SCRIPT="$OPENCODE_CONFIG_DIR/lucebox-autowake-proxy.py"

if [[ ! -x "$START_SCRIPT" ]]; then
  echo "Missing executable start script: $START_SCRIPT" >&2
  echo "Run install-opencode-config-linux.sh first." >&2
  exit 1
fi

if [[ ! -x "$PROXY_SCRIPT" ]]; then
  echo "Missing executable proxy script: $PROXY_SCRIPT" >&2
  echo "Run install-opencode-config-linux.sh first." >&2
  exit 1
fi

mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Lucebox DFlash backend model server
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

cat > "$PROXY_SERVICE_FILE" <<EOF
[Unit]
Description=Lucebox DFlash autowake proxy for OpenCode
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=PYTHONUNBUFFERED=1
Environment=LUCEBOX_BACKEND_SERVICE=$LUCEBOX_SERVICE_NAME.service
Environment=LUCEBOX_PROXY_HOST=$LUCEBOX_PROXY_HOST
Environment=LUCEBOX_PROXY_PORT=$LUCEBOX_PROXY_PORT
Environment=LUCEBOX_BACKEND_URL=$LUCEBOX_BACKEND_URL
Environment=LUCEBOX_BACKEND_HEALTH_URL=$LUCEBOX_BACKEND_HEALTH_URL
Environment=LUCEBOX_IDLE_UNLOAD_SECONDS=$LUCEBOX_IDLE_UNLOAD_SECONDS
Environment=LUCEBOX_START_TIMEOUT_SECONDS=$LUCEBOX_START_TIMEOUT_SECONDS
Environment=LUCEBOX_PROXY_REQUEST_TIMEOUT_SECONDS=$LUCEBOX_PROXY_REQUEST_TIMEOUT_SECONDS
Environment=LUCEBOX_IDLE_POLL_SECONDS=$LUCEBOX_IDLE_POLL_SECONDS
ExecStart=/usr/bin/python3 $PROXY_SCRIPT
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user stop "$LUCEBOX_PROXY_SERVICE_NAME.service" >/dev/null 2>&1 || true
systemctl --user disable "$LUCEBOX_SERVICE_NAME.service" >/dev/null 2>&1 || true
systemctl --user stop "$LUCEBOX_SERVICE_NAME.service" >/dev/null 2>&1 || true
systemctl --user enable --now "$LUCEBOX_PROXY_SERVICE_NAME.service"

echo "Installed $LUCEBOX_SERVICE_NAME.service as on-demand backend"
echo "Installed and started $LUCEBOX_PROXY_SERVICE_NAME.service"
echo "Proxy health: http://$LUCEBOX_HOST:$LUCEBOX_PORT/health"
echo "Backend URL: $LUCEBOX_BACKEND_URL"
