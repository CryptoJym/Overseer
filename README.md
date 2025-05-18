# Overseer Action

This action performs various maintenance tasks when pull requests are merged. It posts a summary to the Memory Graph, creates a follow‑up issue, optionally creates a Todoist task and keeps the project roadmap up to date.

## Inputs

* `github_token` **(required)** – token used to perform API operations.
* `todoist_api_key` – if provided, a task is created in Todoist.
* `new_milestones` – optional JSON describing milestones to append to `ROADMAP.md`.

## Roadmap automation

When a PR is merged the action parses `ROADMAP.md` and checks off any unchecked item whose text appears in the PR title or body. The completion date is appended to the item. New milestones supplied through the `new_milestones` input are added under their corresponding headings.

# Overseer

This repository contains a small GitHub Action that performs follow up tasks when pull requests are merged. Behaviour can be customised via an optional `overseer.config.json` file and a simple CLI is provided for running Overseer locally.

## Configuration

Create `overseer.config.json` in the root of your repository. The file should conform to `config.schema.json` included in this repo. Example:

```json
{
  "memoryMcpUrl": "http://localhost:5000/nodes",
  "todoist": { "enabled": true },
  "prompts": { "summaryPrompt": "Summarise changes" },
  "port": 5000
}
```

- `memoryMcpUrl` – URL to a Memory Graph MCP instance.
- `todoist.enabled` – toggle sending tasks to Todoist.
- `prompts.summaryPrompt` – prompt text used when generating summaries.
- `port` – port for any local services.

## CLI Usage

The `bin/overseer.js` script allows Overseer to be run against a repository outside of GitHub Actions.

Set the following environment variables:

- `GITHUB_TOKEN` – personal access token with repo access.
- `GITHUB_REPO` – repository in `owner/repo` form.
- `TODOIST_API_KEY` – (optional) Todoist API key.

Run:

```bash
node bin/overseer.js               # process latest merged PR
node bin/overseer.js --pr 123       # process PR number 123
```

The script loads `overseer.config.json` from the current working directory and uses the same logic as the GitHub Action.
# Overseer GitHub Action

This action updates your repository roadmap, posts PR summaries to the Memory Graph MCP and creates follow-up GitHub issues.

Todoist tasks are created automatically if a Todoist API key can be found. The key is resolved at runtime from the MCP server configuration (`mcp.json`). When network access is disabled, you may supply the key explicitly using the `TODOIST_API_KEY` environment variable.
