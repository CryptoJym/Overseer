#!/usr/bin/env node
const { Octokit } = require('@octokit/rest');
const { run } = require('../dist/index.js');

async function main() {
  const args = process.argv.slice(2);
  const token = process.env.GITHUB_TOKEN;
  const repoEnv = process.env.GITHUB_REPO;
  if (!token || !repoEnv) {
    console.error('GITHUB_TOKEN and GITHUB_REPO environment variables are required');
    process.exit(1);
  }
  const [owner, repo] = repoEnv.split('/');
  const octokit = new Octokit({ auth: token });

  let prNumber = null;
  if (args[0] === '--pr' && args[1]) {
    prNumber = parseInt(args[1], 10);
  }

  if (!prNumber) {
    const { data: prs } = await octokit.pulls.list({ owner, repo, state: 'closed', sort: 'updated', direction: 'desc', per_page: 10 });
    const merged = prs.find(p => p.merged_at);
    if (!merged) {
      console.error('No merged PRs found');
      process.exit(1);
    }
    prNumber = merged.number;
  }

  const { data: pr } = await octokit.pulls.get({ owner, repo, pull_number: prNumber });
  const { data: files } = await octokit.pulls.listFiles({ owner, repo, pull_number: prNumber, per_page: 100 });
  const changed = files.map(f => `- ${f.filename} (${f.status})`).join('\n');

  const context = {
    payload: { pull_request: pr },
    repo: { owner, repo }
  };

  await run({ context, octokit, githubToken: token, todoistApiKey: process.env.TODOIST_API_KEY, changedFiles: changed });
}

main().catch(err => { console.error(err); process.exit(1); });
