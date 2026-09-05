# Guia Passo a Passo - Configurando no Second Life

## 1. O que voce precisa

- Uma conta no Second Life (preferencialmente Premium para ter terreno proprio).
- Uma TV mesh ou prim simples com uma face frontal para a tela.
- O servidor SL TV Sync rodando na nuvem (siga o README.md).

## 2. Criando a TV dentro do Second Life

### Opcao A: Prim simples (mais facil)

1. Reze um cubo (`Create > Cube`).
2. Ajuste as dimensoes para **X=2.0, Y=0.05, Z=1.125** (aspecto 16:9).
3. Aplique uma textura escura ou transparente nas laterais.
4. A face frontal (face 0) sera onde o video aparece.

### Opcao B: Mesh de TV (mais bonito)

1. Use qualquer mesh TV comprada no Marketplace.
2. Identifique a face da tela (geralmente face 0 ou 1).
3. Anote o numero da face; voce vai alterar no script LSL.

## 3. Colocando o script na TV

1. Clique com o botao direito na TV > **Edit**.
2. Va na aba **Content**.
3. Clique em **New Script**.
4. Apague todo o texto padrao.
5. Cole o conteudo do arquivo `scripts/tv.lsl`.
6. Altere as duas linhas no topo:
   ```lsl
   string SERVER_URL = "https://SEU-SERVIDOR.onrender.com/";
   string CHANNEL_ID = "main-living-room";
   ```
7. Salve com **Ctrl+S**.
8. Feche a janela de edicao.

## 4. Verificando se a tela funcionou

- Se aparecer uma imagem preta ou cinza, clique com botao direito na TV e escolha **Refresh** (ou **Media > Refresh**).
- Se o video nao carregar, verifique:
  - A URL do servidor esta correta?
  - O servidor esta online? (teste a URL no navegador)
  - A face do prim (MEDIA_FACE) e a correta?

## 5. Abrindo o Dashboard

1. No navegador, acesse:
   ```
   https://SEU-SERVIDOR.onrender.com/dashboard.html
   ```
2. Digite o **Admin Secret** (a senha que voce configurou no .env).
3. Escolha um canal (ex: `main-living-room`).
4. Cole uma URL de YouTube embed ou video MP4.
5. Clique em **Load & Play**.
6. A TV no Second Life deve exibir o mesmo conteudo.

## 6. URLs compativeis

### YouTube

Use URLs de embed, nao URLs normais do YouTube.

✅ Correto: `https://www.youtube.com/embed/dQw4w9WgXcQ`

❌ Errado: `https://www.youtube.com/watch?v=dQw4w9WgXcQ`

### Video MP4 direto

✅ Correto: `https://meusite.com/video.mp4`

Selecione **Source Type = Direct** no dashboard.

### Vimeo

Vimeo funciona bem em embeds. Use URLs no formato:
`https://player.vimeo.com/video/123456789`

## 7. Usando multiplas salas (canais)

Cada TV pode usar um canal diferente:

- TV da sala: `main-living-room`
- TV do cinema: `cinema-room`
- TV do clube: `club-house`

O dashboard precisa selecionar o mesmo canal para controlar.

## 8. Controle remoto por chat (opcional)

O script `scripts/remote.lsl` permite controlar a TV digitando comandos no chat local do Second Life (apenas para o dono):

```
/tvplay
/tvpause
/tvstop
/tvload https://www.youtube.com/embed/dQw4w9WgXcQ Meu Video
```

> **Aviso de seguranca:** o remote.lsl guarda o secret no codigo. Qualquer pessoa que consiga ler o script podera controlar a TV. Use apenas para testes pessoais.

## 9. Solucao de problemas

### A tela fica preta

- Verifique se a URL do servidor esta online.
- Clique com botao direito > **Refresh**.
- Tente aumentar o brilho do prim ou reduzir o Glow.
- Verifique se a face do prim e realmente 0.

### O video nao sincroniza

- Verifique se todos os viewers estao na mesma URL/canal.
- O dashboard esta conectado ao mesmo servidor?
- O WebSocket pode ser bloqueado por alguns viewers; recarregue a tela.

### Audio nao sai

- O Second Life Shared Media pode exigir que o usuario clique para habilitar audio.
- O player comeca mudo por padrao devido a politicas de autoplay.
- Para audio, recomenda-se usar um **parcel media stream** separado ou instruir usuarios a interagir.

### O video para sozinho

- Pode ser a politica de autoplay do Chromium do viewer. Use o botao Play no dashboard para reativar.

## 10. Boas praticas

- Use sempre **HTTPS**.
- Escolha um Admin Secret longo e aleatorio.
- Nunca compartilhe o Admin Secret publicamente.
- Teste em uma regiao privada antes de colocar em uma regiao publica lotada.
- Faca backup dos seus scripts LSL fora do Second Life.
