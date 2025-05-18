module.exports = {
  getOctokit: () => ({
    rest: {
      pulls: { listFiles: async () => ({ data: [] }) },
      issues: {
        listForRepo: async () => ({ data: [] }),
        create: async () => ({ data: { number: 1 } }),
        createComment: async () => ({})
      }
    }
  }),
  context: { repo: { owner: 'o', repo: 'r' }, payload: { pull_request: { number: 1, title: '', body: '' } } }
};
