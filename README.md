# Overseer Action

This action performs various maintenance tasks when pull requests are merged. It posts a summary to the Memory Graph, creates a follow‑up issue, optionally creates a Todoist task and keeps the project roadmap up to date.

## Inputs

* `github_token` **(required)** – token used to perform API operations.
* `todoist_api_key` – if provided, a task is created in Todoist.
* `new_milestones` – optional JSON describing milestones to append to `ROADMAP.md`.

## Roadmap automation

When a PR is merged the action parses `ROADMAP.md` and checks off any unchecked item whose text appears in the PR title or body. The completion date is appended to the item. New milestones supplied through the `new_milestones` input are added under their corresponding headings.
