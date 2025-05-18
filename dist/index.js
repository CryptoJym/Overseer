const fs = require('fs');
const path = require('path');
const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');

function loadConfig() {
  const configPath = path.resolve(process.cwd(), 'overseer.config.json');
  if (fs.existsSync(configPath)) {
    try {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch (err) {
      core.warning(`Failed to parse config: ${err.message}`);
    }
  }
  return {};
}

async function run(opts = {}) {
  try {
    const githubToken = opts.githubToken || core.getInput('github_token', { required: true });
    const todoistApiKey = opts.todoistApiKey !== undefined ? opts.todoistApiKey : core.getInput('todoist_api_key');

    const octokit = opts.octokit || github.getOctokit(githubToken);
    const context = opts.context || github.context;
    const config = loadConfig();

    if (!context.payload || !context.payload.pull_request) {
      core.info('No pull_request in context – nothing to do.');
      return;
    }

    const pr = context.payload.pull_request;
    const owner = context.repo.owner;
    const repo = context.repo.repo;

    // 1. Gather PR details
    const prNumber = pr.number;
    core.info(`Processing merged PR #${prNumber}`);

    // Fetch changed files if not supplied
    let changedFiles = opts.changedFiles;
    if (!changedFiles) {
      const filesResp = await octokit.rest.pulls.listFiles({ owner, repo, pull_number: prNumber, per_page: 100 });
      changedFiles = filesResp.data.map(f => `- ${f.filename} (${f.status})`).join('\n');
    }

    // Build summary
    const prSummary = `PR #${prNumber}: ${pr.title}\n\n${pr.body || ''}\n\nChanged files:\n${changedFiles}`;

    // 2. Post to Memory Graph MCP if configured
    try {
      const memoryUrl = config.memoryMcpUrl || process.env.MEMORY_MCP_URL; // e.g., http://localhost:5000/nodes
      if (memoryUrl) {
        await axios.post(memoryUrl, {
          entities: [{ name: `PR-${prNumber}`, entityType: 'pull_request', observations: [prSummary] }]
        });
        core.info('Posted summary to Memory Graph.');
      } else {
        core.info('No memoryMcpUrl set – skipping Memory Graph step.');
      }
    } catch (err) {
      core.warning(`Memory Graph post failed: ${err.message}`);
    }

    // 3. Create follow-up GitHub issue
    const issueTitle = `Follow-up tasks after PR #${prNumber}`;
    const issueBody = `Automatically generated tasks after merging PR #${prNumber}.\n\n### Summary\n${prSummary}\n\n### TODO\n- [ ] Assess refactors\n- [ ] Update documentation\n- [ ] Write tests\n`;

    const issueResp = await octokit.rest.issues.create({ owner, repo, title: issueTitle, body: issueBody });
    core.info(`Created issue #${issueResp.data.number}.`);

    // 4. Send to Todoist if enabled
    const todoistEnabled = config.todoist ? config.todoist.enabled !== false : true;
    if (todoistEnabled && todoistApiKey) {
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

module.exports = { run };

if (require.main === module) {
  run();
}
