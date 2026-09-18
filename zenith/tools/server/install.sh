#!/bin/bash
# Installs or updates the duel server on a Linux box (Debian or Ubuntu). Run as root from the
# directory holding a freshly exported `eidolarch_server.x86_64` (see docs/duel_server.md):
#   bash install.sh [port]
# Safe to run again with a new binary; it restarts the service.
set -e
PORT="${1:-7777}"
install -d /opt/eidolarch
install -m 755 eidolarch_server.x86_64 /opt/eidolarch/eidolarch_server.x86_64
id -u eidolarch >/dev/null 2>&1 || useradd --system --home /opt/eidolarch --shell /usr/sbin/nologin eidolarch
chown -R eidolarch:eidolarch /opt/eidolarch
cat > /etc/systemd/system/eidolarch.service <<UNIT
[Unit]
Description=Eidolarch duel server
After=network-online.target
Wants=network-online.target

[Service]
Environment=GODOT_SILENCE_ROOT_WARNING=1
User=eidolarch
WorkingDirectory=/opt/eidolarch
ExecStart=/usr/bin/stdbuf -oL /opt/eidolarch/eidolarch_server.x86_64 --headless -- --server --port=${PORT}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable eidolarch
systemctl restart eidolarch
if command -v ufw >/dev/null; then
  ufw allow "${PORT}/udp" >/dev/null || true
fi
sleep 2
systemctl --no-pager status eidolarch | head -12
