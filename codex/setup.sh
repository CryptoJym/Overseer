#!/bin/bash
set -e

apt-get update
apt-get install -y postgresql redis-server tree-sitter

pip install mcp-filesystem mcp-git mcp-sqlite mcp-memory mcp-sequential mcp-time mcp-server-aidd

service postgresql start
service redis-server start

nohup python -m mcp.git &
nohup python -m mcp.sqlite &
nohup python -m mcp.filesystem &
nohup python -m mcp.memory &
nohup python -m mcp.sequential &
nohup python -m mcp.time &
nohup python -m mcp.server_aidd &

npm test

