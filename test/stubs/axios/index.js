const http = require('http');
const { URL } = require('url');
module.exports = {
  post: (url, data, opts={}) => new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = http.request({ hostname:u.hostname, port:u.port, path:u.pathname, method:'POST', headers:opts.headers || {'Content-Type':'application/json'} }, res => {
      let body='';
      res.on('data', c=>body+=c);
      res.on('end', () => {
        try { resolve({ data: JSON.parse(body) }); } catch { resolve({ data: body }); }
      });
    });
    req.on('error', reject);
    req.write(JSON.stringify(data));
    req.end();
  }),
  get: (url) => new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = http.request({ hostname:u.hostname, port:u.port, path:u.pathname, method:'GET' }, res => {
      let body='';
      res.on('data', c => body+=c);
      res.on('end', () => resolve({ data: body }));
    });
    req.on('error', reject);
    req.end();
  })
};
