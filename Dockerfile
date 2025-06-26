FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl gnupg ca-certificates \
    iproute2 iptables iputils-ping \
    openssh-server python3 bash && \
    rm -rf /var/lib/apt/lists/*

# Add Tailscale repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | \
    gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" \
    > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Setup root SSH
RUN mkdir -p /root/.ssh /var/run/sshd /var/lib/tailscale /app && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEw0t8Rs56Y76KjWTCtkQBnev2fTxVUQBdmbnc64UWX chatgpt-access" \
    > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

# Force shell to /bin/bash
RUN sed -i 's#^root:.*#root:x:0:0:root:/root:/bin/bash#' /etc/passwd

# Configure sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

# Simple webpage content
RUN echo "🧠 Tailscale SSH + HTTP is running" > /app/index.html

# Env variable for Tailscale key (you pass it from Render)
ENV TS_AUTHKEY=""

# Expose SSH and HTTP ports
EXPOSE 22 8080

# Full entrypoint in CMD (debug and explain everything)
CMD bash -c '\
echo "==================== DEBUG START ===================="; \
echo "[+] Checking /bin/bash availability..."; ls -l /bin/bash || echo "[-] /bin/bash MISSING"; \
echo "[+] Checking root shell in /etc/passwd..."; grep ^root /etc/passwd || echo "[-] Root shell missing"; \
echo "[+] Checking SSH authorized_keys:"; cat /root/.ssh/authorized_keys || echo "[-] No authorized_keys"; \
echo "[+] Starting tailscaled..."; \
tailscaled --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket=/var/run/tailscale/tailscaled.sock & \
for i in {1..30}; do \
  if [ -S /var/run/tailscale/tailscaled.sock ]; then echo "[+] tailscaled socket ready"; break; fi; \
  echo "[-] Waiting for tailscaled socket... ($i)"; sleep 1; done; \
if [ ! -S /var/run/tailscale/tailscaled.sock ]; then \
  echo "[-] ERROR: tailscaled socket not found after 30s"; exit 1; fi; \
echo "[+] Running tailscale up..."; \
tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns || { echo "[-] tailscale up failed"; exit 1; }; \
echo "[+] SSHD config:"; grep -v "^#" /etc/ssh/sshd_config; \
echo "[+] Launching SSHD..."; /usr/sbin/sshd -D -e & \
echo "[+] Launching HTTP server..."; python3 -m http.server 8080 --directory /app & \
echo "[+] Ready! You can SSH using your Tailscale IP/domain"; \
wait -n'
