FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    iproute2 \
    iptables \
    iputils-ping && \
    rm -rf /var/lib/apt/lists/*

# Add Tailscale GPG key and repo
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | \
    gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" \
    > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Prepare tailscaled state directory
RUN mkdir -p /var/lib/tailscale

# Environment variable for auth key (set in Render dashboard)
ENV TS_AUTHKEY=""

# All-in-one startup logic
CMD bash -c '\
  set -e; \
  echo "[+] Starting tailscaled in userspace mode..."; \
  tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock & \
  pid=$!; \
  echo "[+] Waiting for tailscaled socket..."; \
  for i in {1..30}; do \
    [ -S /var/run/tailscale/tailscaled.sock ] && break; \
    sleep 1; \
  done; \
  if [ ! -S /var/run/tailscale/tailscaled.sock ]; then \
    echo "[-] tailscaled socket not found after 30s"; \
    exit 1; \
  fi; \
  echo "[+] Bringing up Tailscale..."; \
  tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns; \
  echo "[+] Tailscale started successfully."; \
  wait $pid'
