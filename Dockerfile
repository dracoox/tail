FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    ca-certificates \
    iproute2 \
    iptables \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Add Tailscale GPG key and repository correctly with signed-by
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Prepare state directory for tailscaled
RUN mkdir -p /var/lib/tailscale

# Default empty env var for Tailscale auth key — set this on Render as env var for security
ENV TS_AUTHKEY=""

# Run tailscaled in userspace networking mode and bring up Tailscale interface with authkey
CMD tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscale.sock & \
    sleep 5 && \
    tailscale up --authkey="${TS_AUTHKEY}" --accept-routes --accept-dns && \
    tail -f /dev/null
