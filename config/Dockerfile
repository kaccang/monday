FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. paket dasar
RUN apt-get update && \
apt-get install -y \
curl \
unzip \
ca-certificates \
supervisor \
openssh-server \
nano \
grep \
cron \
vnstat \
iproute2 \
net-tools && \
mkdir -p /var/run/sshd /var/log/supervisor && \
rm -rf /var/lib/apt/lists/*

# 3. folder xray
RUN mkdir -p /etc/xray /var/log/xray /etc/supervisor && \
chmod 777 /var/log/xray

# 4. copy script CLI kamu ke dalam container
# (pastikan folder /opt/xray/shared/ ada di host)
COPY shared/* /usr/bin/
RUN chmod +x /usr/bin/*

# Auto-jalankan menu saat login (test doang, tulis ke /root/.bashrc)
RUN bash -lc 'if ! grep -q "/usr/bin/menu" /root/.bashrc 2>/dev/null; then echo "/usr/bin/menu" >> /root/.bashrc; fi'

# siapkan folder conf
RUN mkdir -p /root/.config/rclone /etc/rclone /tmp/restore

# 5. copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
