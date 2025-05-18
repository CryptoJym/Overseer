#!/bin/sh
node mcp/sequential.js &
node mcp/memory.js &
node mcp/filesystem.js &
# Keep running
wait
