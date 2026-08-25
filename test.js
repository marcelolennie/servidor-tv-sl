const http = require('http');
const { server, channels } = require('./server.js');

const PORT = 3456;

function request(path, method = 'GET', body = null, secret = null) {
  return new Promise((resolve, reject) => {
    const opts = { hostname: 'localhost', port: PORT, path, method };
    opts.headers = { 'Content-Type': 'application/json' };
    if (secret) opts.headers['Authorization'] = `Bearer ${secret}`;
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  server.listen(PORT, async () => {
    try {
      const health = await request('/health');
      console.log('Health:', health.status, health.body);

      const state = await request('/api/state?channel=main-living-room');
      console.log('State:', state.status, state.body);

      const control = await request('/api/control', 'POST', {
        action: 'change',
        channelId: 'main-living-room',
        url: 'https://www.youtube.com/embed/dQw4w9WgXcQ',
        sourceType: 'youtube',
        title: 'Test Video'
      }, 'change-me-now');
      console.log('Control:', control.status, control.body);

      const addPl = await request('/api/control', 'POST', {
        action: 'add',
        channelId: 'main-living-room',
        url: 'https://www.youtube.com/embed/abc123',
        title: 'Playlist Item',
        sourceType: 'youtube'
      }, 'change-me-now');
      console.log('Add playlist:', addPl.status, addPl.body);

      const channelsList = await request('/api/channels');
      console.log('Channels:', channelsList.status, channelsList.body);

      const secondChannel = await request('/api/state?channel=cinema-room');
      console.log('Second channel exists:', secondChannel.status, secondChannel.body.includes('cinema-room'));

      console.log('All tests passed.');
    } catch (e) {
      console.error('Test failed:', e.message);
      process.exitCode = 1;
    } finally {
      server.close(() => process.exit(process.exitCode || 0));
    }
  });
}

run();
