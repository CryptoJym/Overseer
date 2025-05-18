const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');
const fs = require('fs');
const { spawn } = require('child_process');

function buildPrompt(prSummary, roadmapTasks) {
  const roadmapSection = roadmapTasks.length ? `\n\nOpen roadmap tasks:\n- ${roadmapTasks.join('\n- ')}` : '';
  return `Using the PR summary below, suggest follow up tasks as a JSON array.\n\nPR Summary:\n${prSummary}${roadmapSection}`;
}

function parseTasks(respData) {
  try {
    if (typeof respData === 'string') {
      return JSON.parse(respData).tasks || [];
    }
    return respData.tasks || [];
  } catch (e) {
    return [];
  }
}

async function getRoadmapTasks() {
  try {
    const content = fs.readFileSync('ROADMAP.md', 'utf8');
    return content.split('\n').filter(l => l.startsWith('- [ ]')).map(l => l.replace(/^- \[ \] /, '').trim());
  } catch (e) {
    return [];
  }
}

async function callMcp(prompt, port) {
  const url = `http://localhost:${port}/`;
  const res = await axios.post(url, { prompt });
  return parseTasks(res.data);
}

async function run() {
  try {
    const githubToken = core.getInput('github_token', { required: true });
    const todoistApiKey = core.getInput('todoist_api_key');
    if (todoistApiKey) core.setSecret(todoistApiKey);

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

    // Start MCP server
    const mcpPort = process.env.MCP_PORT || 7000;
    core.info(`Starting MCP server on port ${mcpPort}`);
    const mcpProc = spawn('npx', ['-y', '@modelcontextprotocol/server-sequential-thinking', '--port', mcpPort], { stdio: 'inherit' });
    await new Promise(r => setTimeout(r, 2000));

    const roadmapTasks = await getRoadmapTasks();
    const prompt = buildPrompt(prSummary, roadmapTasks);

    let tasks = [];
    try {
      tasks = await callMcp(prompt, mcpPort);
    } catch (err) {
      core.warning(`MCP call failed: ${err.message}`);
    } finally {
      mcpProc.kill();
    }

    if (!tasks.length) {
      core.info('No follow-up tasks received from MCP.');
      return;
    }

    // Create GitHub issues for each task
    for (const t of tasks) {
      const title = t.title || t;
      const body = t.body || `Task generated from PR #${prNumber}.`;

      // search for existing umbrella issue
      const { data: issues } = await octokit.rest.issues.listForRepo({ owner, repo, state: 'open', per_page: 100 });
      let existing = issues.find(i => i.title === title);
      if (existing) {
        await octokit.rest.issues.createComment({ owner, repo, issue_number: existing.number, body });
        core.info(`Appended comment to issue #${existing.number}`);
      } else {
        const resp = await octokit.rest.issues.create({ owner, repo, title, body });
        core.info(`Created issue #${resp.data.number}.`);
      }
    }

    // 4. Send to Todoist if API key provided
    if (todoistApiKey) {
      try {
        await axios.post('https://api.todoist.com/rest/v2/tasks', {
          content: `Repo ${repo}: Follow-up tasks from PR #${prNumber}`,
          description: 'See GitHub issues for details',
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

module.exports = { run, buildPrompt, parseTasks, callMcp };

if (require.main === module) {
  run();
}
