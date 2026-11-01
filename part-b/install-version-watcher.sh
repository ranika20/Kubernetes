#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="/usr/local/lib/fortune-api-version-watcher"
WATCHER="$LIB_DIR/watch-version.sh"
SERVICE_FILE="/etc/systemd/system/fortune-api-version-watcher.service"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this installer with sudo: sudo bash $SCRIPT_DIR/install-version-watcher.sh" >&2
  exit 1
fi

if [[ ! -x "$(command -v systemctl || true)" ]]; then
  echo "systemctl is required to install the version watcher." >&2
  exit 1
fi

if [[ ! -f "$SCRIPT_DIR/VERSION" || ! -f "$SCRIPT_DIR/deploy.sh" || ! -f "$SCRIPT_DIR/watch-version.sh" ]]; then
  echo "VERSION, deploy.sh, or watch-version.sh is missing from $SCRIPT_DIR." >&2
  exit 1
fi

install -d -o root -g root -m 0755 "$LIB_DIR"
install -o root -g root -m 0755 "$SCRIPT_DIR/deploy.sh" "$LIB_DIR/deploy.sh"
install -o root -g root -m 0755 "$SCRIPT_DIR/watch-version.sh" "$WATCHER"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Deploy Fortune API when the local VERSION file changes
After=network-online.target k3s.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$SCRIPT_DIR
Environment=FORTUNE_API_PROJECT_DIR=$SCRIPT_DIR
ExecStart=/usr/bin/bash $WATCHER
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now fortune-api-version-watcher.service
systemctl restart fortune-api-version-watcher.service
systemctl --no-pager --full status fortune-api-version-watcher.service
