const express = require('express');
const app = express();
const http = require('http').createServer(app);
const io = require('socket.io')(http, { cors: { origin: "*" } });
const path = require('path');
const ytSearch = require('yt-search'); // Biblioteca de busca do YouTube

const PORT = process.env.PORT || 3000;
app.use(express.static(path.join(__dirname, 'public')));

const tvRooms = {};

io.on('connection', (socket) => {
    
    // 1. Entrar na Sala
    socket.on('joinRoom', (roomId) => {
        socket.join(roomId);
        if (!tvRooms[roomId]) {
            tvRooms[roomId] = {
                currentVideoId: 'fhiKEaCndG0', // Vídeo Cyberpunk inicial
                currentTime: 0,
                isPlaying: false,
                lastUpdated: Date.now()
            };
        }
        
        const room = tvRooms[roomId];
        let tempoAtual = room.currentTime;
        if (room.isPlaying) {
            tempoAtual += (Date.now() - room.lastUpdated) / 1000;
        }
        socket.emit('sync', { ...room, currentTime: tempoAtual });
    });

    // 2. Comandos da TV (Play, Pause, Mudar Vídeo)
    socket.on('command', (data) => {
        const { roomId, action, videoId, time } = data;
        if (!tvRooms[roomId]) return;
        
        const room = tvRooms[roomId];

        if (action === 'play') {
            room.isPlaying = true;
            room.currentTime = time || room.currentTime;
            room.lastUpdated = Date.now();
        } else if (action === 'pause') {
            room.isPlaying = false;
            room.currentTime = time || room.currentTime;
            room.lastUpdated = Date.now();
        } else if (action === 'changeVideo') {
            room.currentVideoId = videoId;
            room.currentTime = 0;
            room.isPlaying = true;
            room.lastUpdated = Date.now();
        }
        
        // Avisa a todos da sala
        io.to(roomId).emit('sync', room);
    });

    // 3. Sistema de Busca do YouTube (Pesquisa sem API Key!)
    socket.on('searchYouTube', async (query, roomId) => {
        try {
            const r = await ytSearch(query);
            const videos = r.videos.slice(0, 8); // Pega os 8 primeiros resultados
            socket.emit('searchResults', videos); // Envia de volta para quem pesquisou
        } catch(err) {
            console.error("Erro na busca:", err);
        }
    });
});

http.listen(PORT, () => {
    console.log(`Servidor Premium rodando na porta ${PORT}`);
});