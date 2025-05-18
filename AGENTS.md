# Codex Bootstrap Instructions

## Languages & Directories
- **Node.js**: application source in `bin/`, compiled action in `dist/`, tests in `__tests__/`, MCP servers in `mcp/`.

## Build, Lint, Test
- Install dependencies with `npm install`.
- Run tests with `npm test` (uses Jest).

## Docker Usage
Build and run the Codex development image:
```sh
docker build -t repo-dev .
docker run --rm -it repo-dev ./codex/setup.sh
```

The container exposes MCP servers on ports `7000-7005`. Outbound-network MCP servers are intentionally excluded.
