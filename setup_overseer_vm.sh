#!/bin/bash
set -euo pipefail

# This script installs everything needed to run the Overseer Action locally.
# It should be executed on a fresh VM with internet access. After completion
# the VM can be used offline.

# Default ports for MCP servers
MEMORY_PORT=5000
SEQ_THINK_PORT=5001
FILESYSTEM_PORT=5002
GIT_PORT=5003
TIME_PORT=5004

# Update packages and install prerequisites
sudo apt-get update -y
sudo apt-get install -y curl git

# Install Node.js LTS and npm from NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install pm2 and required MCP servers globally
sudo npm install -g pm2 \
  @modelcontextprotocol/server-memory \
  @modelcontextprotocol/server-sequential-thinking \
  @modelcontextprotocol/server-filesystem \
  @modelcontextprotocol/server-git \
  @modelcontextprotocol/server-time

# Start MCP servers using pm2
pm2 start $(which server-memory) --name mcp-memory -- --port "$MEMORY_PORT"
pm2 start $(which server-sequential-thinking) --name mcp-sequential-thinking -- --port "$SEQ_THINK_PORT"
pm2 start $(which server-filesystem) --name mcp-filesystem -- --port "$FILESYSTEM_PORT"
pm2 start $(which server-git) --name mcp-git -- --port "$GIT_PORT"
pm2 start $(which server-time) --name mcp-time -- --port "$TIME_PORT"

# Configure pm2 to run on boot
pm2 save
pm2 startup systemd -u "${SUDO_USER:-$USER}" --hp "$HOME"

# Optionally install Docker and pull images specified via DOCKER_IMAGES
if [ "${INSTALL_DOCKER:-yes}" = "yes" ]; then
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
  if [ -n "${DOCKER_IMAGES:-}" ]; then
    for img in $DOCKER_IMAGES; do
      sudo docker pull "$img"
    done
  fi
fi

# Smoke test each MCP server
for port in "$MEMORY_PORT" "$SEQ_THINK_PORT" "$FILESYSTEM_PORT" "$GIT_PORT" "$TIME_PORT"; do
  echo "Testing MCP on port $port..."
  if curl -fsS "http://localhost:$port" >/dev/null; then
    echo "Port $port OK"
  else
    echo "Warning: no response on port $port" >&2
  fi
done

echo "Setup complete."
