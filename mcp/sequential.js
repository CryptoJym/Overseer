const http = require('http');

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/run') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ result: 'sequential-thoughts' }));
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(7000, () => console.log('Sequential MCP listening on 7000'));
