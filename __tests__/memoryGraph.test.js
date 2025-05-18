const axios = require('axios');
jest.mock('axios');

const { postMemoryGraph } = require('../dist/index');

beforeEach(() => {
  axios.post.mockReset();
});

describe('postMemoryGraph', () => {
  test('posts when url provided', async () => {
    axios.post.mockResolvedValue({});
    await postMemoryGraph('http://localhost:1234/nodes', 1, 'summary');
    expect(axios.post).toHaveBeenCalledWith('http://localhost:1234/nodes', {
      entities: [{ name: 'PR-1', entityType: 'pull_request', observations: ['summary'] }]
    });
  });

  test('skips when url missing', async () => {
    await postMemoryGraph('', 1, 'summary');
    expect(axios.post).not.toHaveBeenCalled();
  });
});
