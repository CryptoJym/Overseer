const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');
const fs = require('fs');
const { execSync } = require('child_process');

function locateMcpConfig() {
  const envPath = process.env.MCP_CONFIG;
  if (envPath && fs.existsSync(envPath)) {
    return envPath;
  }
  try {
    const output = execSync('find / -name mcp.json 2>/dev/null', { encoding: 'utf8' });
    const first = output.split('\n').find(Boolean);
    return first || null;
  } catch (_e) {
    return null;
  }
}

function getTodoistApiKey() {
  if (process.env.TODOIST_API_KEY) {
    return process.env.TODOIST_API_KEY;
  }
  const configPath = locateMcpConfig();
  if (!configPath) {
    return null;
  }
  try {
    const data = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    if (data.todoist_api_key) return data.todoist_api_key;
    if (data.todoist && data.todoist.api_key) return data.todoist.api_key;
  } catch (_e) {}
  return null;
}

async function run() {
  try {
    const githubToken = core.getInput('github_token', { required: true });
    const todoistApiKey = getTodoistApiKey();

    const octokit = github.getOctokit(githubToken);
    const { context } = github;

    if (!context.payload.pull_request) {
      core.info('No pull_request in context – nothing to do.');
      return;
    }

    const pr = context.payload.pull_request;
    const owner = context.repo.owner;
    const repo = context.repo.repo;

    // 1. Gather PR details
    const prNumber = pr.number;
    core.info(`Processing merged PR #${prNumber}`);

    // Fetch changed files
    const filesResp = await octokit.rest.pulls.listFiles({ owner, repo, pull_number: prNumber, per_page: 100 });
    const changedFiles = filesResp.data.map(f => `- ${f.filename} (${f.status})`).join('\n');

    // Build summary
    const prSummary = `PR #${prNumber}: ${pr.title}\n\n${pr.body || ''}\n\nChanged files:\n${changedFiles}`;

    // 2. (Placeholder) Post to Memory Graph MCP
    try {
      const memoryUrl = process.env.MEMORY_MCP_URL; // e.g., http://localhost:5000/nodes
      if (memoryUrl) {
        await axios.post(memoryUrl, {
          entities: [{ name: `PR-${prNumber}`, entityType: 'pull_request', observations: [prSummary] }]
        });
        core.info('Posted summary to Memory Graph.');
      } else {
        core.info('MEMORY_MCP_URL not set – skipping Memory Graph step.');
      }
    } catch (err) {
      core.warning(`Memory Graph post failed: ${err.message}`);
    }

    // 3. Create follow-up GitHub issue
    const issueTitle = `Follow-up tasks after PR #${prNumber}`;
    const issueBody = `Automatically generated tasks after merging PR #${prNumber}.\n\n### Summary\n${prSummary}\n\n### TODO\n- [ ] Assess refactors\n- [ ] Update documentation\n- [ ] Write tests\n`;

    const issueResp = await octokit.rest.issues.create({ owner, repo, title: issueTitle, body: issueBody });
    core.info(`Created issue #${issueResp.data.number}.`);

    // 4. Send to Todoist if API key provided
    if (todoistApiKey) {
      try {
        await axios.post('https://api.todoist.com/rest/v2/tasks', {
          content: `Repo ${repo}: ${issueTitle}`,
          description: 'See GitHub issue for details',
        }, {
          headers: { Authorization: `Bearer ${todoistApiKey}` }
        });
        core.info('Task sent to Todoist.');
      } catch (err) {
        core.warning(`Todoist sync failed: ${err.message}`);
      }
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();