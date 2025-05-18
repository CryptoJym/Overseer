const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');
const { spawn } = require('child_process');

async function ensureMemoryServer(memoryUrl) {
  const baseUrl = new URL(memoryUrl).origin;
  try {
    await axios.get(baseUrl);
  } catch (_) {
    core.info('Starting local Memory Graph MCP server...');
    const child = spawn('npx', ['-y', '@modelcontextprotocol/server-memory'], {
      detached: true,
      stdio: 'ignore'
    });
    child.unref();
    await new Promise(res => setTimeout(res, 1000));
  }
}

async function persistToMemory({ prNumber, prSummary, mergedBy, closedIssues, memoryUrl }) {
  await ensureMemoryServer(memoryUrl);
  const payload = {
    entities: [
      {
        name: `PR-${prNumber}`,
        entityType: 'pull_request',
        observations: [
          { summary: prSummary, timestamp: new Date().toISOString(), merged_by: mergedBy }
        ]
      }
    ],
    relations: closedIssues.map(id => ({
      source: `PR-${prNumber}`,
      type: 'implements',
      target: `Issue-${id}`
    }))
  };
  await axios.post(`${memoryUrl}/nodes`, payload);
}

async function run() {
  try {
    const githubToken = core.getInput('github_token', { required: true });
    const todoistApiKey = core.getInput('todoist_api_key');

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

    // 2. Persist PR info to Memory Graph MCP
    const memoryUrl = process.env.MEMORY_MCP_URL || 'http://localhost:5000';
    try {
      const issueRegex = /(close[sd]?|fix(?:es|ed)?|resolve[sd]?)\s+#(\d+)/gi;
      const closedIssues = [];
      let match;
      while ((match = issueRegex.exec(pr.body || '')) !== null) {
        closedIssues.push(match[2]);
      }
      await persistToMemory({
        prNumber,
        prSummary,
        mergedBy: pr.merged_by.login,
        closedIssues,
        memoryUrl
      });
      core.info('Posted summary to Memory Graph.');
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

if (require.main === module) {
  run();
} else {
  module.exports = { run, persistToMemory, ensureMemoryServer };
}
