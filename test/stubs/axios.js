const http = require('http');
const https = require('https');

function request(method, url, data) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const opts = { method, hostname: u.hostname, port: u.port, path: u.pathname, headers: { 'Content-Type': 'application/json' } };
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(opts, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve({ data: body ? JSON.parse(body) : {} }); }
        catch(e) { resolve({ data: {} }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}
module.exports = { get: url => request('GET', url), post: (url, data) => request('POST', url, data) };

