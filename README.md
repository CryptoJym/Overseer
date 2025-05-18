# Overseer GitHub Action

This action updates your repository roadmap, posts PR summaries to the Memory Graph MCP and creates follow-up GitHub issues.

Todoist tasks are created automatically if a Todoist API key can be found. The key is resolved at runtime from the MCP server configuration (`mcp.json`). When network access is disabled, you may supply the key explicitly using the `TODOIST_API_KEY` environment variable.
