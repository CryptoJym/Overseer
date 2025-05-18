module.exports = {
  getOctokit: () => ({ rest: { pulls: { listFiles: async () => ({ data: [] }) }, issues: { create: async () => ({ data: { number: 1 } }) } } }),
  context: { repo: { owner: 'test', repo: 'repo' }, payload: { pull_request: { number: 1 } }, actor: 'tester' }
};

