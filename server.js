/**
 * SL TV Sync Server
 * Backend central que coordena o que todos os viewers da TV assistem.
 */
require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const PORT = process.env.PORT || 3000;
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'change-me-now';

// Salas de TV em memória (em produção, use Redis para escalar).
const channels = new Map();
const viewerCounts = new Map();

function ensureChannel(channelId) {
  if (!channels.has(channelId)) {
    channels.set(channelId, {
      channelId,
      url: 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&controls=0',
      sourceType: 'youtube',
      isPlaying: true,
      position: 0,
      lastUpdate: Date.now(),
      volume: 80,
      title: 'Welcome to SL TV Sync',
      playlist: [],
      currentIndex: 0
    });
    viewerCounts.set(channelId, 0);
  }
  return channels.get(channelId);
}

function getCurrentPosition(state) {
  if (state.isPlaying && state.lastUpdate) {
    const elapsed = (Date.now() - state.lastUpdate) / 1000;
    return state.position + elapsed;
  }
  return state.position;
}

function broadcastState(channelId) {
  const state = ensureChannel(channelId);
  state.lastUpdate = Date.now();
  state.position = getCurrentPosition(state);
  io.to(channelId).emit('tv:update', {
    ...state,
    viewers: viewerCounts.get(channelId) || 0
  });
}

function requireAdmin(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (token !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

function applyAction(state, data) {
  const { action, url, sourceType, position, volume, title, index } = data;

  if (title !== undefined) state.title = title;
  if (volume !== undefined) state.volume = Math.max(0, Math.min(100, volume));

  switch (action) {
    case 'play':
      state.isPlaying = true;
      state.position = position !== undefined ? position : getCurrentPosition(state);
      break;
    case 'pause':
      state.position = getCurrentPosition(state);
      state.isPlaying = false;
      break;
    case 'seek':
      state.position = position || 0;
      break;
    case 'change':
      if (!url) throw new Error('url required');
      state.url = url;
      state.sourceType = sourceType || 'youtube';
      state.position = 0;
      state.isPlaying = true;
      state.title = title || 'Untitled Stream';
      break;
    case 'stop':
      state.isPlaying = false;
      state.position = 0;
      break;
    case 'add':
      if (!url) throw new Error('url required');
      state.playlist.push({ url, sourceType: sourceType || 'youtube', title: title || 'Untitled' });
      break;
    case 'remove':
      if (index !== undefined && index >= 0 && index < state.playlist.length) {
        state.playlist.splice(index, 1);
      }
      break;
    case 'next':
      if (state.playlist.length > 0) {
        state.currentIndex = (state.currentIndex + 1) % state.playlist.length;
        const item = state.playlist[state.currentIndex];
        state.url = item.url;
        state.sourceType = item.sourceType || 'youtube';
        state.title = item.title || 'Playlist Item';
        state.position = 0;
        state.isPlaying = true;
      }
      break;
    case 'prev':
      if (state.playlist.length > 0) {
        state.currentIndex = (state.currentIndex - 1 + state.playlist.length) % state.playlist.length;
        const item = state.playlist[state.currentIndex];
        state.url = item.url;
        state.sourceType = item.sourceType || 'youtube';
        state.title = item.title || 'Playlist Item';
        state.position = 0;
        state.isPlaying = true;
      }
      break;
    case 'clear':
      state.playlist = [];
      state.currentIndex = 0;
      break;
    default:
      throw new Error('Unknown action');
  }
}

app.get('/api/state', (req, res) => {
  const channelId = req.query.channel || 'main-living-room';
  const state = ensureChannel(channelId);
  res.json({
    ...state,
    position: getCurrentPosition(state),
    viewers: viewerCounts.get(channelId) || 0
  });
});

app.get('/api/state/:channelId', (req, res) => {
  const state = ensureChannel(req.params.channelId);
  res.json({
    ...state,
    position: getCurrentPosition(state),
    viewers: viewerCounts.get(req.params.channelId) || 0
  });
});

app.get('/api/channels', (req, res) => {
  const list = Array.from(channels.keys()).map(id => ({
    channelId: id,
    viewers: viewerCounts.get(id) || 0,
    title: channels.get(id).title
  }));
  res.json(list);
});

app.post('/api/control', requireAdmin, (req, res) => {
  try {
    const channelId = req.body.channelId || 'main-living-room';
    const state = ensureChannel(channelId);
    applyAction(state, req.body);
    broadcastState(channelId);
    res.json(state);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

io.on('connection', (socket) => {
  let channelId = 'main-living-room';

  socket.on('join', (id) => {
    if (id) channelId = id;
    socket.join(channelId);
    viewerCounts.set(channelId, (viewerCounts.get(channelId) || 0) + 1);
    const state = ensureChannel(channelId);
    socket.emit('tv:update', {
      ...state,
      position: getCurrentPosition(state),
      viewers: viewerCounts.get(channelId) || 0
    });
    broadcastState(channelId);
  });

  socket.on('admin:control', (data) => {
    if (data.secret !== ADMIN_SECRET) {
      socket.emit('error', 'Unauthorized');
      return;
    }
    const ch = data.channelId || channelId;
    const state = ensureChannel(ch);
    try {
      applyAction(state, data);
      broadcastState(ch);
    } catch (e) {
      socket.emit('error', e.message);
    }
  });

  socket.on('viewer:requestSync', () => {
    const state = ensureChannel(channelId);
    socket.emit('tv:update', {
      ...state,
      position: getCurrentPosition(state),
      viewers: viewerCounts.get(channelId) || 0
    });
  });

  socket.on('disconnect', () => {
    viewerCounts.set(channelId, Math.max(0, (viewerCounts.get(channelId) || 0) - 1));
    broadcastState(channelId);
  });
});

app.get('/health', (req, res) => res.json({ ok: true, channels: channels.size }));

if (require.main === module) {
  server.listen(PORT, () => {
    console.log(`SL TV Sync server running on port ${PORT}`);
    console.log(`Dashboard: http://localhost:${PORT}/dashboard.html`);
    console.log(`TV Player: http://localhost:${PORT}/`);
  });
}

module.exports = { app, server, io, channels, viewerCounts };
