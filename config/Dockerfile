FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. Paket dasar (lengkap)
RUN apt-get update && \
    apt-get install -y \
    curl wget unzip ca-certificates \
    supervisor openssh-server cron \
    vnstat iproute2 net-tools jq nano grep lsb-release && \
    mkdir -p /var/run/sshd /var/log/supervisor && \
    rm -rf /var/lib/apt/lists/*

# 2. Folder dasar
RUN mkdir -p /etc/xray /var/log/xray /etc/supervisor /root/.ssh && \
    chmod 700 /root/.ssh && chmod 777 /var/log/xray

# 3. Auto-run menu saat login shell (opsional)
RUN bash -lc 'if ! grep -q "/usr/bin/menu" /root/.bashrc 2>/dev/null; then echo "/usr/bin/menu" >> /root/.bashrc; fi'

# 4. Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 5. Manage Menu
#COPY menu/shared/* /usr/bin/
#RUN chmod +x /usr/bin/*

ENTRYPOINT ["/entrypoint.sh"]
