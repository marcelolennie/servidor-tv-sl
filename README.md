# SL TV Sync - TV Sincronizada para Second Life

Projeto completo para criar uma **TV inteligente e sincronizada dentro do Second Life**. Tudo o que o dono tocar no dashboard aparece ao mesmo tempo para todos os avatares que estiverem olhando para a tela.

## Funcionalidades

- **Sincronizacao em tempo real** via WebSocket (menos de 1 segundo de delay).
- **Dashboard moderna** com dark theme, controle de play/pause/seek/volume e playlist.
- **Multiplos canais/salas** para ter varias TVs independentes.
- **Player web otimizado** para Shared Media do Second Life (autoplay, sem controles, aspecto 16:9).
- **Scripts LSL prontos** para colocar dentro da TV e controle remoto opcional.
- **API REST** para integracao com outros sistemas.
- **Contador de viewers** ao vivo.

## Arquivos do projeto

```
sl-tv-sync/
├── server.js                 # Backend Node.js + Express + Socket.IO
├── public/
│   ├── index.html            # Player web exibido na TV do SL
│   └── dashboard.html        # Painel de controle do dono
├── scripts/
│   ├── tv.lsl                # Script LSL para a TV
│   └── remote.lsl            # Script LSL de controle remoto (opcional)
├── render.yaml               # Configuracao de deploy no Render.com
├── setup.sh                  # Script de setup rapido local
├── test.js                   # Testes automatizados
├── .env.example              # Exemplo de variaveis de ambiente
├── .gitignore
├── README.md                 # Este guia
└── GUIA-SECONDLIFE.md        # Passo a passo detalhado dentro do SL
```

## Como funciona

1. O servidor Node.js mantem o estado atual (URL, posicao, play/pause, volume).
2. A TV no Second Life carrega o player web (`index.html`) em uma face do prim usando Shared Media.
3. Cada viewer conectado se conecta ao servidor via WebSocket.
4. Quando o dono muda de video no dashboard, todos os viewers recebem o novo estado instantaneamente.
5. Quando alguem entra tarde, o player busca a posicao exata para comecar no mesmo ponto.

## Requisitos

- Node.js 18 ou superior.
- Conta em algum servico de nuvem (recomendamos Render.com).
- Conta no Second Life com permissoes para editar prims.

## 1. Testar localmente

```bash
npm install
npm start
```

Acesse:
- **Dashboard:** http://localhost:3000/dashboard.html
- **TV Player:** http://localhost:3000/?channel=main-living-room
- **Health:** http://localhost:3000/health

Ou use o script de setup:

```bash
bash setup.sh
```

## 2. Deploy na nuvem (Render.com - recomendado)

### 2.1. Criar repositorio no GitHub

1. Crie um novo repositorio no GitHub.
2. Faca upload dos arquivos deste projeto.
3. Certifique-se de que o arquivo `render.yaml` esta na raiz.

### 2.2. Criar o servico no Render

1. Acesse [render.com](https://render.com) e crie uma conta gratuita.
2. Clique em **New + Web Service**.
3. Conecte o repositorio do GitHub.
4. O Render deve detectar automaticamente o `render.yaml`.
5. Se nao detectar, configure manualmente:
   - **Environment:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
6. Adicione a variavel de ambiente:
   - `ADMIN_SECRET` = uma senha forte (ex: `sltv2024_super_seguro_xyz`)
7. Clique em **Create Web Service**.
8. Aguarde o deploy (cerca de 2-5 minutos).
9. Anote a URL publica gerada (ex: `https://sl-tv-sync-abc.onrender.com`).

### 2.3. Outras nuvens

O projeto funciona em qualquer placaforma que rode Node.js:

- **Railway:** importe o repositorio, defina `npm start` e `ADMIN_SECRET`.
- **Fly.io:** use `fly launch` com um Dockerfile basico ou Node nativo.
- **AWS/VPS:** rode `npm install` e `npm start` com PM2 ou systemd.

## 3. Configurar a TV dentro do Second Life

Veja o arquivo **GUIA-SECONDLIFE.md** para instrucoes completas com imagens mentais e troubleshooting.

Resumo rapido:

1. Edite o arquivo `scripts/tv.lsl`.
2. Altere `SERVER_URL` para a URL do seu servidor.
3. Cole o script dentro do prim da TV (Edit > Content > New Script).
4. Ajuste a face da tela (normalmente 0).
5. Pronto! A TV ja exibe o player.

## 4. Usar a Dashboard

1. Abra no navegador:
   ```
   https://SEU-SERVIDOR.onrender.com/dashboard.html
   ```
2. Insira o **Admin Secret**.
3. Selecione o mesmo canal configurado na TV.
4. Cole a URL de um video e clique em **Load & Play**.
5. Todos que estiverem vendo a TV no Second Life verao o mesmo conteudo.

## 5. Controle remoto por chat (opcional)

Use `scripts/remote.lsl` para permitir comandos no chat local:

```
/tvplay
/tvpause
/tvstop
/tvload https://www.youtube.com/embed/dQw4w9WgXcQ Meu Video
```

> **Seguranca:** este script guarda o Admin Secret em texto plano. Use apenas para testes pessoais.

## 6. Testes automatizados

```bash
node test.js
```

O teste verifica:
- Endpoint de health.
- Leitura do estado.
- Controle de video.
- Adicao a playlist.
- Multiplos canais.

## 7. Limitacoes conhecidas

- O sincronismo nao e frame-perfect, mas e praticamente simultaneo para a maioria dos casos.
- Autoplay com audio pode ser bloqueado pelos navegadores; o player comeca mudo por padrao.
- Videos do YouTube precisam permitir incorporacao (embed).
- O Second Life Shared Media depende do viewer de cada usuario; conexoes lentas podem atrasar levemente.

## 8. Seguranca

- Altere `ADMIN_SECRET` para algo longo e unico.
- Nunca publique o `.env` no GitHub (ele ja esta no `.gitignore`).
- Nao compartilhe o secret em scripts LSL publicos.
- Para produccao, considere autenticacao por token por usuario.

## 9. Licenca

MIT. Use para criar sua TV no Second Life e vender no Marketplace se desejar.

---

**Bora assistir junto no Second Life!**
