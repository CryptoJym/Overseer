const assert = require('assert');
const http = require('http');
const { persistToMemory } = require('../dist/index');

async function runTest() {
  const memoryUrl = 'http://localhost:5555';
  const prNumber = 42;
  const prSummary = 'Summary text';
  const mergedBy = 'tester';
  const closedIssues = ['99'];

  let received = null;
  const server = http.createServer((req, res) => {
    if (req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{}');
    } else {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        received = JSON.parse(body);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end('{"ok":true}');
      });
    }
  });

  await new Promise(r => server.listen(5555, r));
  await persistToMemory({ prNumber, prSummary, mergedBy, closedIssues, memoryUrl });
  server.close();

  assert.strictEqual(received.entities[0].name, 'PR-42');
  assert.strictEqual(received.entities[0].observations[0].merged_by, 'tester');
  assert.strictEqual(received.relations[0].target, 'Issue-99');
  console.log('Test passed');
}

runTest().catch(err => {
  console.error(err);
  process.exit(1);
});


