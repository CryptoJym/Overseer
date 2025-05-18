const express = require('express');
jest.setTimeout(30000);

jest.mock('@actions/core', () => ({
  getInput: jest.fn((name) => {
    if (name === 'github_token') return 'x';
    if (name === 'todoist_api_key') return 'tok';
  }),
  info: jest.fn(),
  warning: jest.fn(),
  setFailed: jest.fn()
}));

jest.mock('@actions/github', () => {
  const context = {
    payload: {
      pull_request: {
        number: 1,
        title: 'T',
        body: 'B'
      }
    },
    repo: { owner: 'me', repo: 'r' }
  };
  return {
    context,
    getOctokit: jest.fn(() => ({
      rest: {
        pulls: {
          listFiles: jest.fn().mockResolvedValue({ data: [{ filename: 'f.js', status: 'added' }] })
        },
        issues: {
          create: jest.fn().mockResolvedValue({ data: { number: 2 } })
        }
      }
    }))
  };
});

const { run } = require('../dist/index');

let memoryBody;
let todoistBody;
let memoryServer;
let todoistServer;

beforeAll((done) => {
  const app1 = express();
  app1.use(express.json());
  app1.post('/nodes', (req, res) => { memoryBody = req.body; res.sendStatus(200); });
  memoryServer = app1.listen(0, () => {
    const { port } = memoryServer.address();
    process.env.MEMORY_MCP_URL = `http://localhost:${port}/nodes`;
    const app2 = express();
    app2.use(express.json());
    app2.post('/tasks', (req, res) => { todoistBody = req.body; res.sendStatus(200); });
    todoistServer = app2.listen(0, () => {
      const { port: p2 } = todoistServer.address();
      process.env.TODOIST_API_URL = `http://localhost:${p2}`;
      done();
    });
  });
});

afterAll((done) => {
  memoryServer.close(() => {
    todoistServer.close(done);
  });
});

test('run posts to servers', async () => {
  await run();
  expect(memoryBody).toBeTruthy();
  expect(todoistBody).toBeTruthy();
});
