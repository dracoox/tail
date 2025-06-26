FROM ubuntu:22.04

# Install necessary packages and Tailscale
RUN apt-get update && apt-get install -y \
    curl iproute2 iptables ca-certificates gnupg iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Add Tailscale repo and install tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Prepare state directory
RUN mkdir -p /var/lib/tailscale

# Default empty auth key; set your key on Render dashboard environment variables
ENV TS_AUTHKEY=""

# Start tailscaled in userspace networking mode, then bring interface up using auth key
CMD tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscale.sock & \
    sleep 5 && \
    tailscale up --authkey="${TS_AUTHKEY}" --accept-routes --accept-dns && \
    tail -f /dev/null
