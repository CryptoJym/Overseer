const http = require('http');

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/nodes') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(7001, () => console.log('Memory MCP listening on 7001'));
