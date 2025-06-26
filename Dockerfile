FROM ubuntu:22.04

# Install base packages
RUN apt-get update && apt-get install -y \
    curl gnupg ca-certificates \
    iproute2 iptables iputils-ping \
    openssh-server \
    python3 && \
    rm -rf /var/lib/apt/lists/*

# Add Tailscale GPG key and repo
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Prepare SSH and authorized key
RUN mkdir -p /var/run/sshd /root/.ssh /var/lib/tailscale /app && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEw0t8Rs56Y76KjWTCtkQBnev2fTxVUQBdmbnc64UWX chatgpt-access" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

# Disable password login for security
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Add test file to /app
RUN echo "Hello from Render + Tailscale + SSH!" > /app/index.html

# Set env for Tailscale auth key (set on Render)
ENV TS_AUTHKEY=""

# Expose SSH and HTTP ports
EXPOSE 22 8080

# Startup script: Tailscale, then SSH + HTTP
CMD bash -c '\
  set -e; \
  echo "[+] Starting tailscaled..."; \
  tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock & \
  pid=$!; \
  for i in {1..30}; do \
    [ -S /var/run/tailscale/tailscaled.sock ] && break; \
    sleep 1; \
  done; \
  if [ ! -S /var/run/tailscale/tailscaled.sock ]; then \
    echo "[-] tailscaled socket not found after 30s"; exit 1; fi; \
  echo "[+] Tailscale up..."; \
  tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns; \
  echo "[+] Starting SSH + HTTP..."; \
  /usr/sbin/sshd && python3 -m http.server 8080 --directory /app & \
  wait $pid'
