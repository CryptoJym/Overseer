const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url.startsWith('/read/')) {
    const file = path.join(process.cwd(), req.url.replace('/read/', ''));
    fs.readFile(file, 'utf8', (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('Not found');
      } else {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(data);
      }
    });
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(7002, () => console.log('Filesystem MCP listening on 7002'));
