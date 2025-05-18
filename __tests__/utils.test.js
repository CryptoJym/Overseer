const fs = require('fs');
const path = require('path');
const nock = require('nock');
const { parseRoadmap, buildPrompt, callMcp } = require('../dist/index');

describe('roadmap parsing', () => {
  test('reads open tasks', () => {
    const file = path.join(__dirname, 'ROADMAP.md');
    fs.writeFileSync(file, '- [ ] task one\n- [x] done\n- [ ] task two\n');
    expect(parseRoadmap(file)).toEqual(['task one', 'task two']);
    fs.unlinkSync(file);
  });
});

describe('MCP call', () => {
  test('parses tasks from response', async () => {
    const scope = nock('http://localhost:7000').post('/').reply(200, {
      tasks: [{ title: 'a', body: '' }]
    });
    const tasks = await callMcp('prompt', 7000);
    expect(tasks).toEqual([{ title: 'a', body: '' }]);
    expect(scope.isDone()).toBe(true);
  });

  test('throws on invalid response', async () => {
    nock('http://localhost:7000').post('/').reply(200, {});
    await expect(callMcp('prompt', 7000)).rejects.toThrow('Invalid MCP response');
  });
});
