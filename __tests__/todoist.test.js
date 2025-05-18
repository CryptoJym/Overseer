const axios = require('axios');
jest.mock('axios');

const { postTodoist } = require('../dist/index');

beforeEach(() => {
  axios.post.mockReset();
});

describe('postTodoist', () => {
  test('posts when key provided', async () => {
    axios.post.mockResolvedValue({});
    process.env.TODOIST_API_URL = 'http://localhost:5555';
    await postTodoist('tok', 'repo', 'title');
    expect(axios.post).toHaveBeenCalledWith('http://localhost:5555/tasks', {
      content: 'Repo repo: title',
      description: 'See GitHub issue for details'
    }, { headers: { Authorization: 'Bearer tok' } });
  });

  test('skips when no key', async () => {
    await postTodoist('', 'repo', 'title');
    expect(axios.post).not.toHaveBeenCalled();
  });
});
