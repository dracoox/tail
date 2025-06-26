FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    iproute2 \
    iptables \
    iputils-ping \
    openssh-server \
    python3 \
    bash && \
    rm -rf /var/lib/apt/lists/*

# Add Tailscale GPG key and repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Setup SSH for root user
RUN mkdir -p /var/run/sshd /root/.ssh /var/lib/tailscale /app && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEw0t8Rs56Y76KjWTCtkQBnev2fTxVUQBdmbnc64UWX chatgpt-access" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

# Set root login shell
RUN chsh -s /bin/bash root

# Configure SSHD
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Create sample file for HTTP server
RUN echo "Hello from Tailscale SSH + Web Server!" > /app/index.html

# Set Tailscale auth key (use environment in Render)
ENV TS_AUTHKEY=""

# Expose SSH and HTTP ports
EXPOSE 22 8080

# Start Tailscale, SSHD (in foreground), and HTTP server
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
  echo "[+] Running tailscale up..."; \
  tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns; \
  echo "[+] Starting SSHD + HTTP server..."; \
  /usr/sbin/sshd -D & \
  python3 -m http.server 8080 --directory /app & \
  wait $pid'
