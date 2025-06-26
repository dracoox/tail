FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl gnupg ca-certificates \
    iproute2 iptables iputils-ping \
    openssh-server python3 bash && \
    rm -rf /var/lib/apt/lists/*

# Add Tailscale repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Setup SSH and directories
RUN mkdir -p /root/.ssh /var/run/sshd /var/lib/tailscale /app && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEw0t8Rs56Y76KjWTCtkQBnev2fTxVUQBdmbnc64UWX chatgpt-access" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    touch /app/sshd.log

# Force root shell to bash
RUN sed -i 's#^root:.*#root:x:0:0:root:/root:/bin/bash#' /etc/passwd

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

# Web content
RUN echo "🧠 Tailscale SSH + HTTP is running" > /app/index.html

ENV TS_AUTHKEY=""

EXPOSE 22 8080

CMD bash -c '\
echo "[+] Starting tailscaled..." && \
tailscaled --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock & \
TAILPID=$!; \
for i in {1..30}; do \
  [ -S /var/run/tailscale/tailscaled.sock ] && break; \
  echo "[-] Waiting for tailscaled... ($i)" >> /app/sshd.log; \
  sleep 1; \
done; \
[ -S /var/run/tailscale/tailscaled.sock ] || { echo "[-] Tailscale socket failed" >> /app/sshd.log; exit 1; }; \
echo "[+] Running tailscale up..." >> /app/sshd.log; \
tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns >> /app/sshd.log 2>&1 || echo "[-] tailscale up failed" >> /app/sshd.log; \
echo "[+] Starting SSHD..." >> /app/sshd.log; \
/usr/sbin/sshd -D -e >> /app/sshd.log 2>&1 & \
echo "[+] Starting HTTP server..." >> /app/sshd.log; \
python3 -m http.server 8080 --directory /app & \
wait $TAILPID'
