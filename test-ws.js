const { server } = require('./server.js');
const io = require('socket.io-client');
const http = require('http');

const PORT = 3457;
const SECRET = 'change-me-now';

function request(path, method, body) {
  return new Promise((resolve, reject) => {
    const opts = { hostname: 'localhost', port: PORT, path, method };
    opts.headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${SECRET}` };
    const req = http.request(opts, res => { let d=''; res.on('data',c=>d+=c); res.on('end',()=>resolve({status:res.statusCode, body:d})); });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  server.listen(PORT, async () => {
    const updates = [];

    const viewer1 = io(`http://localhost:${PORT}`);
    const viewer2 = io(`http://localhost:${PORT}`);

    viewer1.on('connect', () => viewer1.emit('join', 'test-room'));
    viewer2.on('connect', () => viewer2.emit('join', 'test-room'));

    viewer1.on('tv:update', (state) => { updates.push({ viewer: 1, title: state.title }); });
    viewer2.on('tv:update', (state) => { updates.push({ viewer: 2, title: state.title }); });

    // Aguarda conexoes.
    await new Promise(r => setTimeout(r, 800));

    // Admin muda video via HTTP.
    await request('/api/control', 'POST', {
      action: 'change', channelId: 'test-room', url: 'https://www.youtube.com/embed/test123', sourceType: 'youtube', title: 'Synced Test'
    });

    // Aguarda broadcast.
    await new Promise(r => setTimeout(r, 500));

    const v1Updates = updates.filter(u => u.viewer === 1 && u.title === 'Synced Test');
    const v2Updates = updates.filter(u => u.viewer === 2 && u.title === 'Synced Test');

    console.log('Viewer 1 received update:', v1Updates.length > 0);
    console.log('Viewer 2 received update:', v2Updates.length > 0);

    const ok = v1Updates.length > 0 && v2Updates.length > 0;

    viewer1.close();
    viewer2.close();
    server.close(() => process.exit(ok ? 0 : 1));
  });
}

run();
