Overseer GitHub Action that reacts to merged pull requests.

The action now persists structured information about each PR into a local
Memory Graph MCP instance. If the server is not running it will automatically
start `npx -y @modelcontextprotocol/server-memory`.

Unit tests can be run with `npm test` and use a mock Memory MCP endpoint.
