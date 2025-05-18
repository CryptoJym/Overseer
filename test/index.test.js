const assert = require('assert');
const http = require('http');
const Module = require('module');
process.env.NODE_PATH = __dirname + '/stubs';
Module._initPaths();

const { parseTasks, callMcp } = require('../dist/index');

// parseTasks happy path
assert.deepStrictEqual(parseTasks('{"tasks":[{"title":"a"}]}')[0].title, 'a');
assert.deepStrictEqual(parseTasks({tasks:[{title:'b'}]})[0].title, 'b');
assert.deepStrictEqual(parseTasks('bad json'), []);

// callMcp happy path using stub server
const tasks = [{title:'x'},{title:'y'}];
const server = http.createServer((req,res)=>{
  let body='';
  req.on('data',d=>body+=d);
  req.on('end',()=>{
    res.writeHead(200, {'Content-Type':'application/json'});
    res.end(JSON.stringify({tasks}));
  });
});
server.listen(0, async () => {
  const port = server.address().port;
  const resp = await callMcp('hi', port);
  assert.deepStrictEqual(resp, tasks);
  server.close(runErrorTest);
});

function runErrorTest(){
  const badServer = http.createServer((req,res)=>{
    res.writeHead(500);
    res.end('error');
  });
  badServer.listen(0, async ()=>{
    const port = badServer.address().port;
    try {
      await callMcp('hi', port);
      assert.fail('should throw');
    } catch(e){
      assert.ok(e);
    }
    badServer.close(()=>console.log('tests passed'));
  });
}
