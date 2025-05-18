const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');
const fs = require('fs');
const {spawn} = require('child_process');

function parseRoadmap(filePath) {
  if (!fs.existsSync(filePath)) return [];
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  return lines.filter(l => l.startsWith('- [ ]')).map(l => l.replace('- [ ]', '').trim());
}

function buildPrompt(prSummary, roadmapTasks) {
  const tasksSection = roadmapTasks.length ? roadmapTasks.map(t => `- ${t}`).join('\n') : 'None';
  return `PR Summary:\n${prSummary}\n\nOpen Roadmap Tasks:\n${tasksSection}\n\nRespond with JSON {"tasks":[{"title":"","body":""}]}`;
}

async function callMcp(prompt, port) {
  const url = `http://localhost:${port}/`;
  const resp = await axios.post(url, {prompt});
  if (!resp.data || !Array.isArray(resp.data.tasks)) {
    throw new Error('Invalid MCP response');
  }
  return resp.data.tasks;
}

async function run() {
  try {
    const githubToken = core.getInput('github_token', { required: true });
    core.setSecret(githubToken);

    const octokit = github.getOctokit(githubToken);
    const { context } = github;

    if (!context.payload.pull_request) {
      core.info('No pull_request in context – nothing to do.');
      return;
    }

    const pr = context.payload.pull_request;
    const owner = context.repo.owner;
    const repo = context.repo.repo;

    const prNumber = pr.number;
    core.info(`Processing merged PR #${prNumber}`);

    const filesResp = await octokit.rest.pulls.listFiles({ owner, repo, pull_number: prNumber, per_page: 100 });
    const changedFiles = filesResp.data.map(f => `- ${f.filename} (${f.status})`).join('\n');

    const prSummary = `PR #${prNumber}: ${pr.title}\n\n${pr.body || ''}\n\nChanged files:\n${changedFiles}`;

    const roadmapTasks = parseRoadmap('ROADMAP.md');
    const prompt = buildPrompt(prSummary, roadmapTasks);

    const mcpPort = process.env.SEQUENTIAL_MCP_PORT || '7000';
    let mcpTasks = [];
    try {
      const proc = spawn('npx', ['-y', '@modelcontextprotocol/server-sequential-thinking'], {
        env: { ...process.env, PORT: mcpPort },
        stdio: 'ignore',
        detached: true
      });
      proc.unref();
      await new Promise(res => setTimeout(res, 2000));
      mcpTasks = await callMcp(prompt, mcpPort);
    } catch (err) {
      core.warning(`MCP call failed: ${err.message}`);
    }

    let umbrella = null;
    try {
      const { data: issues } = await octokit.rest.issues.listForRepo({ owner, repo, state: 'open', per_page: 100 });
      umbrella = issues.find(i => i.title === 'Follow-up tasks');
    } catch (err) {
      core.warning(`Listing issues failed: ${err.message}`);
    }

    if (umbrella) {
      const newBody = (umbrella.body || '') + '\n' + mcpTasks.map(t => `- [ ] ${t.title}`).join('\n');
      await octokit.rest.issues.update({ owner, repo, issue_number: umbrella.number, body: newBody });
    } else {
      for (const task of mcpTasks) {
        await octokit.rest.issues.create({ owner, repo, title: task.title, body: task.body || '' });
      }
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

if (require.main === module) {
  run();
}

module.exports = { run, parseRoadmap, buildPrompt, callMcp };
