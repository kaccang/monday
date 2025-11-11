#!/bin/bash
set -e
# Log error startup biar gampang debug
exec 2> >(tee /var/log/entrypoint-error.log >&2)

: "${SSH_PORT:=2200}"
: "${ROOT_PASSWORD:=root123}"
: "${XRAY_DOMAIN:=example.com}"
: "${XRAY_HOSTNAME:=container}"   # akan diset sesuai nama anchor dari host
: "${VNSTAT_IFACE:=}"             # kalau kosong, autodetect

BASE_LINK="https://github.com/kaccang/monday/raw/main"
MENU_LINK="$BASE_LINK/menu/shared"

echo "━━━━━━━━ ENTRYPOINT ━━━━━━━━"
echo "[INFO] SSH_PORT=${SSH_PORT}"
echo "[INFO] XRAY_HOSTNAME=${XRAY_HOSTNAME}"

# ====== Direktori wajib ======
mkdir -p /root/menu /var/run/sshd /var/log/xray /var/log/supervisor /etc/xray
chmod 755 /var/log/xray

# ====== Unduh menu CLI (tetap lengkap) ======
FILES=( add-ws del-ws renew-ws cek-ws user-ws menu )
for file in "${FILES[@]}"; do
    echo "[DL] $file"
    wget -q -O "/usr/bin/$file" "$MENU_LINK/$file" || echo "⚠️ Gagal unduh $file"
    chmod +x "/usr/bin/$file" || true
done

# ====== Seed file info (domain/org/city) ======
# (Kalau kamu mount file ini dari host, baris berikut tetap harmless)
echo "${XRAY_DOMAIN}" > /etc/xray/domain
curl -s ipinfo.io/org  | cut -d ' ' -f 2- > /etc/xray/org  || true
curl -s ipinfo.io/city > /etc/xray/city                   || true

# ====== SSH ======
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/'             /etc/ssh/sshd_config || true
echo "root:${ROOT_PASSWORD}" | chpasswd

# ====== Hostname (HARUS sesuai anchor) ======
echo "$XRAY_HOSTNAME" > /etc/hostname
hostname "$XRAY_HOSTNAME" || true
grep -q "$XRAY_HOSTNAME" /etc/hosts || echo "127.0.1.1   $XRAY_HOSTNAME" >> /etc/hosts
echo "[INFO] Hostname set: $(hostname)"

# ====== VNSTAT (autodetect iface + init) ======
if [ -z "$VNSTAT_IFACE" ]; then
  VNSTAT_IFACE="$(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo|veth|br-|docker0)$' | head -n1)"
  [ -z "$VNSTAT_IFACE" ] && VNSTAT_IFACE="eth0"
fi
echo "[VNSTAT] iface: ${VNSTAT_IFACE}"
mkdir -p /var/lib/vnstat
/usr/sbin/vnstatd --initdb 2>/dev/null || true
vnstat --add -i "${VNSTAT_IFACE}" 2>/dev/null || vnstat -u -i "${VNSTAT_IFACE}" 2>/dev/null || true

# ====== CONFIG XRAY (download default hanya bila kosong) ======
if [ ! -s /etc/xray/config.json ]; then
  echo "[XRAY] Downloading default config.json..."
  wget -q -O /etc/xray/config.json "$BASE_LINK/config/config.json"
fi

# ====== SUPERVISOR: sshd + vnstatd + cron (lengkap) ======
cat >/etc/supervisor/supervisord.conf <<EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[program:sshd]
command=/usr/sbin/sshd -D -p ${SSH_PORT}
autostart=true
autorestart=true
stdout_logfile=/var/log/xray/ssh-out.log
stderr_logfile=/var/log/xray/ssh-err.log

[program:vnstatd]
command=/usr/sbin/vnstatd --nodaemon --startempty
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/vnstatd.log
stderr_logfile=/var/log/supervisor/vnstatd.err.log
environment=VNSTAT_INTERFACE="${VNSTAT_IFACE}"

[program:cron]
command=/usr/sbin/cron -f
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/cron.log
stderr_logfile=/var/log/supervisor/cron.err
EOF

echo "[SUPERVISOR] Launching services..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
