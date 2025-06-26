FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    iproute2 \
    iptables \
    iputils-ping \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Add Tailscale GPG key and repository
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | \
    gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" \
    > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Create directory for tailscaled and web files
RUN mkdir -p /var/lib/tailscale /app

# Add a test file to serve (optional)
RUN echo "Hello from your Tailscale-powered server!" > /app/index.html

# Set environment variable for Tailscale auth key (use Render ENV)
ENV TS_AUTHKEY=""

# Expose the HTTP server port
EXPOSE 8080

# Start tailscaled, wait, bring up Tailscale, and launch HTTP server
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
    echo "[-] tailscaled socket not found after 30s"; \
    exit 1; \
  fi; \
  echo "[+] Bringing up Tailscale..."; \
  tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns; \
  echo "[+] Tailscale started. Serving files on :8080..."; \
  python3 -m http.server 8080 --directory /app & \
  wait $pid'
