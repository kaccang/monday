#!/bin/bash
set -e

: "${SSH_PORT:=2200}"
: "${XRAY_DOMAIN:=example.com}"
: "${ROOT_PASSWORD:=root123}"
: "${XRAY_HOSTNAME:=}"   # hostname dari luar (opsional)

# Buat direktori menu
mkdir -p /root/menu/

BASE_LINK="https://github.com/kaccang/monday/raw/main"
MENU_LINK="$BASE_LINK/menu"

# Daftar file yang akan diunduh
FILES=(
    "add-ws"
    "cek-ws"
    "del-ws"
    "menu"
    "renew-ws"
    "user-ws"
)

# Unduh & pasang file 
for file in "${FILES[@]}"; do
    wget -q -O "/usr/bin/$file" "$MENU_LINK/$file"
    chmod +x "/usr/bin/$file"
done

mkdir -p /var/run/sshd /var/log/xray /var/log/supervisor /etc/xray

# simpan domain buat script add-vless, add-vmess, dll
echo "${XRAY_DOMAIN}" > /etc/xray/domain
curl -s ipinfo.io/org | cut -d ' ' -f 2- > /etc/xray/isp
curl -s ipinfo.io/city > /etc/xray/city

# ====== SSH CONFIG ======
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || true
sed -i 's/^#PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config || true
echo "root:${ROOT_PASSWORD}" | chpasswd

# ====== HOSTNAME (NON-FATAL) ======
if [ -n "$XRAY_HOSTNAME" ]; then
  echo "$XRAY_HOSTNAME" > /etc/hostname || true
  hostname "$XRAY_HOSTNAME" 2>/dev/null || true
  if ! grep -q "$XRAY_HOSTNAME" /etc/hosts; then
    echo "127.0.1.1   $XRAY_HOSTNAME" >> /etc/hosts || true
  fi
fi

# ====== VNSTAT ======
if [ -z "$VNSTAT_IFACE" ]; then
  echo "[vnstat] VNSTAT_IFACE belum di-set, deteksi otomatis..."
  VNSTAT_IFACE="$(
    ip -o link show 2>/dev/null \
      | awk -F': ' '{print $2}' \
      | grep -v '^lo$' \
      | grep -v '^docker0$' \
      | grep -v '^veth' \
      | grep -v '^br-' \
      | head -n1
  )"
  [ -z "$VNSTAT_IFACE" ] && VNSTAT_IFACE="eth0"
  echo "[vnstat] pakai interface: ${VNSTAT_IFACE}"
else
  echo "[vnstat] VNSTAT_IFACE dari ENV: ${VNSTAT_IFACE}"
fi

mkdir -p /var/lib/vnstat
set +e
/usr/sbin/vnstatd --initdb 2>/dev/null
vnstat --add -i "${VNSTAT_IFACE}" 2>/dev/null || vnstat -u -i "${VNSTAT_IFACE}" 2>/dev/null
set -e

# ====== XRAY CONFIG ======
if [ ! -s /etc/xray/config.json ]; then
wget -O /etc/xray/config.json "$BASE_LINK/config/config.json
fi

# ====== SUPERVISOR ======
cat >/etc/supervisor/supervisord.conf <<EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log

[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[program:sshd]
command=/usr/sbin/sshd -D -p ${SSH_PORT}
autorestart=true
stdout_logfile=/var/log/xray/ssh-out.log
stderr_logfile=/var/log/xray/ssh-err.log

[program:vnstatd]
command=/usr/sbin/vnstatd --nodaemon --startempty
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/vnstatd.log
stderr_logfile=/var/log/supervisor/vnstatd.err.log

[program:cron]
command=/usr/sbin/cron -f
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/cron.log
stderr_logfile=/var/log/supervisor/cron.err
EOF

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
