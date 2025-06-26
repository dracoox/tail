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

# Add Tailscale GPG key and repo
RUN curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.gpg | gpg --dearmor -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu jammy main" > /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y tailscale

# Setup SSH keys and directories
RUN mkdir -p /var/run/sshd /root/.ssh /var/lib/tailscale /app && \
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEw0t8Rs56Y76KjWTCtkQBnev2fTxVUQBdmbnc64UWX chatgpt-access" > /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys

# Force root shell to bash
RUN sed -i 's#^root:.*#root:x:0:0:root:/root:/bin/bash#' /etc/passwd

# Configure sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

# Create sample HTTP file
RUN echo "Hello from Tailscale SSH + Web Server!" > /app/index.html

# Create embedded entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "[+] Starting tailscaled..."\n\
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &\n\
for i in {1..30}; do\n\
  if [ -S /var/run/tailscale/tailscaled.sock ]; then\n\
    echo "[+] tailscaled socket found."\n\
    break\n\
  fi\n\
  echo "[+] Waiting for tailscaled socket... ($i)"\n\
  sleep 1\n\
done\n\
if [ ! -S /var/run/tailscale/tailscaled.sock ]; then\n\
  echo "[-] tailscaled socket not found after 30 seconds, exiting."\n\
  exit 1\n\
fi\n\
echo "[+] Running tailscale up..."\n\
tailscale up --authkey=${TS_AUTHKEY} --accept-routes --accept-dns\n\
echo "[+] Starting SSHD (debug mode) and HTTP server..."\n\
/usr/sbin/sshd -D -e &\n\
python3 -m http.server 8080 --directory /app &\n\
wait -n\n\
echo "[!] One of the processes exited, shutting down."\n\
exit 1\n' > /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Set Tailscale auth key environment variable (set this at runtime)
ENV TS_AUTHKEY=""

# Expose ports
EXPOSE 22 8080

# Use our embedded entrypoint script as CMD
CMD ["/entrypoint.sh"]
