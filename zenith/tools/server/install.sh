#!/bin/bash
# Installs or updates the duel server on a Linux box (Debian or Ubuntu). Run as root from the
# directory holding a freshly exported `eidolarch_server.x86_64` (see docs/duel_server.md):
#   bash install.sh [port] [data dir] [host name]
# Safe to run again with a new binary; it restarts the service. The data dir (default
# /var/lib/eidolarch) holds the match records and their signing key, and the DTLS key and
# certificate the server makes on its first start: owned by the service user, mode 0700, and the
# service runs with umask 0077 so every file it makes there is 0600. The host name goes into the
# certificate, and clients check it against the address they dial, so pass the box's public
# address (deploy.ps1 does).
set -e
PORT="${1:-7777}"
DATA_DIR="${2:-/var/lib/eidolarch}"
HOST_NAME="${3:-eidolarch}"
install -d /opt/eidolarch
install -m 755 eidolarch_server.x86_64 /opt/eidolarch/eidolarch_server.x86_64
id -u eidolarch >/dev/null 2>&1 || useradd --system --home /opt/eidolarch --shell /usr/sbin/nologin eidolarch
chown -R eidolarch:eidolarch /opt/eidolarch
install -d -m 700 -o eidolarch -g eidolarch "${DATA_DIR}"
chown eidolarch:eidolarch "${DATA_DIR}"
chmod 700 "${DATA_DIR}"
cat > /etc/systemd/system/eidolarch.service <<UNIT
[Unit]
Description=Eidolarch duel server
After=network-online.target
Wants=network-online.target

[Service]
Environment=GODOT_SILENCE_ROOT_WARNING=1
User=eidolarch
UMask=0077
WorkingDirectory=/opt/eidolarch
ExecStart=/usr/bin/stdbuf -oL /opt/eidolarch/eidolarch_server.x86_64 --headless -- --server --port=${PORT} --data-dir=${DATA_DIR} --host-name=${HOST_NAME}
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
# The first start makes the DTLS key and certificate, which takes a moment on a small box.
for _ in $(seq 1 20); do
  [ -f "${DATA_DIR}/dtls.crt" ] && break
  sleep 1
done
systemctl --no-pager status eidolarch | head -12
if [ -f "${DATA_DIR}/dtls.crt" ]; then
  echo "DTLS certificate for $(cat "${DATA_DIR}/dtls.name" 2>/dev/null): ${DATA_DIR}/dtls.crt"
  echo "Clients pin it as zenith/data/net/duel_server.crt (deploy.ps1 copies it there)."
else
  echo "No DTLS certificate at ${DATA_DIR}/dtls.crt yet. See journalctl -u eidolarch."
fi
