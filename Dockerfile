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

# Add Tailscale GPG key properly with dearmor and add repo
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Prepare directory for tailscale state
RUN mkdir -p /var/lib/tailscale

# Environment variable for auth key (set this at runtime)
ENV TS_AUTHKEY=""

# Run tailscaled in userspace mode and authenticate with authkey; keep container alive
CMD tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscale.sock & \
    sleep 5 && \
    tailscale up --authkey="${TS_AUTHKEY}" --accept-routes --accept-dns && \
    tail -f /dev/null
