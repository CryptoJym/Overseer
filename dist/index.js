const core = require('@actions/core');
const github = require('@actions/github');
const axios = require('axios');

async function run() {
  try {
    const githubToken = core.getInput('github_token', { required: true });
    const todoistApiKey = core.getInput('todoist_api_key');
    const newMilestonesInput = core.getInput('new_milestones');

    const octokit = github.getOctokit(githubToken);
    const { context } = github;

    if (!context.payload.pull_request) {
      core.info('No pull_request in context – nothing to do.');
      return;
    }

    const pr = context.payload.pull_request;
    if (!pr.merged) {
      core.info('PR was not merged – skipping.');
      return;
    }

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

    // 5. Update roadmap if present
    try {
      const roadmapPath = 'ROADMAP.md';
      const roadmapResp = await octokit.rest.repos.getContent({ owner, repo, path: roadmapPath, ref: 'main' });
      const roadmapSha = roadmapResp.data.sha;
      let roadmapContent = Buffer.from(roadmapResp.data.content, 'base64').toString('utf8');
      const mergeDate = pr.merged_at ? pr.merged_at.split('T')[0] : new Date().toISOString().split('T')[0];

      const prText = `${pr.title}\n${pr.body || ''}`;
      const lines = roadmapContent.split(/\r?\n/);
      let changed = false;
      for (let i = 0; i < lines.length; i++) {
        const match = lines[i].match(/^(- \[( |x)\] )(.*)$/i);
        if (match && match[2] === ' ' && prText.includes(match[3])) {
          lines[i] = `- [x] ${match[3]} (${mergeDate})`;
          changed = true;
        }
      }

      // Append new milestones
      if (newMilestonesInput) {
        try {
          const milestones = JSON.parse(newMilestonesInput);
          for (const section of milestones) {
            const heading = section.heading;
            const items = section.items || [];
            let idx = lines.findIndex(l => l.trim().toLowerCase() === `## ${heading}`.toLowerCase());
            if (idx === -1) {
              lines.push(`\n## ${heading}`);
              idx = lines.length - 1;
            }
            for (const item of items) {
              lines.splice(idx + 1, 0, `- [ ] ${item}`);
              idx++;
            }
          }
          changed = true;
        } catch (err) {
          core.warning(`Failed to parse new_milestones: ${err.message}`);
        }
      }

      if (changed) {
        roadmapContent = lines.join('\n');
        const encoded = Buffer.from(roadmapContent).toString('base64');
        const commitMessage = `chore: update roadmap after PR #${prNumber}`;

        async function attemptUpdate() {
          try {
            await octokit.rest.repos.createOrUpdateFileContents({
              owner,
              repo,
              path: roadmapPath,
              message: commitMessage,
              content: encoded,
              sha: roadmapSha,
              branch: 'main'
            });
            core.info('ROADMAP.md updated.');
          } catch (err) {
            if (err.status === 409) {
              core.warning('Conflict updating ROADMAP.md, retrying...');
              const latest = await octokit.rest.repos.getContent({ owner, repo, path: roadmapPath, ref: 'main' });
              roadmapSha = latest.data.sha;
              roadmapContent = Buffer.from(latest.data.content, 'base64').toString('utf8');
              // TODO: reapply changes - keeping simple by appending merge marker
              const retryLines = roadmapContent.split(/\r?\n/);
              for (let i = 0; i < retryLines.length; i++) {
                const match = retryLines[i].match(/^(- \[( |x)\] )(.*)$/i);
                if (match && match[2] === ' ' && prText.includes(match[3])) {
                  retryLines[i] = `- [x] ${match[3]} (${mergeDate})`;
                }
              }
              roadmapContent = retryLines.join('\n');
              const retryEncoded = Buffer.from(roadmapContent).toString('base64');
              await octokit.rest.repos.createOrUpdateFileContents({
                owner,
                repo,
                path: roadmapPath,
                message: commitMessage,
                content: retryEncoded,
                sha: roadmapSha,
                branch: 'main'
              });
              core.info('ROADMAP.md updated after retry.');
            } else {
              throw err;
            }
          }
        }

        await attemptUpdate();
      }
    } catch (err) {
      core.warning(`Roadmap update failed: ${err.message}`);
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
