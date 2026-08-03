const express = require('express');
const app = express();
app.use(express.static('public'));
const http = require('http').createServer(app);
const io = require('socket.io')(http, {
    cors: { origin: "*" } // Permite que a tela da TV se conecte de qualquer lugar
});

const PORT = process.env.PORT || 3000;

// Este é o "banco de dados" na memória. Guarda o que está tocando na TV de cada cliente.
const tvRooms = {};

io.on('connection', (socket) => {
    
    // 1. Quando uma TV liga, ela pede para entrar na sua própria Sala (usando o UUID do Second Life)
    socket.on('joinRoom', (roomId) => {
        socket.join(roomId);

        // Se o cliente acabou de comprar a TV, a sala não existe. Criamos uma com um vídeo padrão.
        if (!tvRooms[roomId]) {
            tvRooms[roomId] = {
                currentVideoId: 'dQw4w9WgXcQ', // Vídeo inicial
                currentTime: 0,
                isPlaying: false,
                lastUpdated: Date.now()
            };
        }

        const room = tvRooms[roomId];
        
        // Calcula em qual segundo o vídeo está exatamente AGORA
        let tempoAtual = room.currentTime;
        if (room.isPlaying) {
            const delta = (Date.now() - room.lastUpdated) / 1000;
            tempoAtual += delta;
        }

        // Manda o vídeo e o tempo exato só para quem acabou de chegar perto dessa TV
        socket.emit('sync', { ...room, currentTime: tempoAtual });
    });

    // 2. Quando o dono da TV aperta Play, Pause ou muda de vídeo
    socket.on('command', (data) => {
        const { roomId, action, videoId, time } = data;
        
        // Se a sala não existe, ignora
        if (!tvRooms[roomId]) return;

        const room = tvRooms[roomId];

        if (action === 'play') {
            room.isPlaying = true;
            room.currentTime = time || room.currentTime;
            room.lastUpdated = Date.now();
        } 
        else if (action === 'pause') {
            room.isPlaying = false;
            room.currentTime = time || room.currentTime;
            room.lastUpdated = Date.now();
        } 
        else if (action === 'changeVideo') {
            room.currentVideoId = videoId;
            room.currentTime = 0;
            room.isPlaying = true;
            room.lastUpdated = Date.now();
        }

        // A MÁGICA: Avisa TODOS os avatares que estão olhando para ESSA TV específica para atualizarem a tela
        io.to(roomId).emit('sync', room);
    });
});

http.listen(PORT, () => {
    console.log(`Servidor da TV rodando perfeitamente na porta ${PORT}`);
});