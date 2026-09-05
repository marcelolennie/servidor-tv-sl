# 🎯 Guia Passo a Passo — Construir Mesa de Hand & Foot Canasta no Second Life

Este guia detalha **todos os passos** para construir sua mesa de Hand & Foot Canasta no Second Life, desde a criação dos prims até o teste final.

---

## 📦 Pré-requisitos

- Conta Second Life com permissão de upload (L$40 para 4 texturas)
- Viewer com suporte a LSL (Firestorm recomendado)
- Arquivos deste projeto baixados no seu computador

---

## FASE 1: Upload de Texturas

### Passo 1.1 — Upload dos atlas de cartas

1. No inventário do SL, clique **Upload → Image** (ou L$10 por upload)
2. Selecione `assets/cards_atlas_1.png` → Upload
3. Selecione `assets/cards_atlas_2.png` → Upload
4. Selecione `assets/card_back.png` → Upload
5. Selecione `assets/table_felt.png` → Upload

> **Custo total: L$40** (4 texturas × L$10)

### Passo 1.2 — Copiar UUIDs das texturas

Para cada textura no inventário:
1. Clique com botão direito → **Copy Asset UUID**
   - (Se não aparecer, ative em **Me → Preferences → Advanced → Show Asset IDs**)
2. Anote os UUIDs em um arquivo de texto

Você precisará de 3 UUIDs:
- `ATLAS1_UUID` = UUID de `cards_atlas_1`
- `ATLAS2_UUID` = UUID de `cards_atlas_2`
- `CARDBACK_UUID` = UUID de `card_back`

### Passo 1.3 — Editar o notecard de configuração

Abra `notecards/HF_Config.txt` e substitua os UUIDs:

```
ATLAS1_UUID=seu-uuid-aqui
ATLAS2_UUID=seu-uuid-aqui
CARDBACK_UUID=seu-uuid-aqui
```

---

## FASE 2: Construir os Prims da Mesa

### Passo 2.1 — Prim Raiz (Mesa/Tampo)

1. **Build → Create → Cylinder** (ou Box arredondado)
2. Posição: center da região
3. Tamanho: `<2.5, 2.5, 0.08>` (diâmetro 2.5m, espessura 8cm)
4. Textura: aplique `table_felt.png` (UUID copiado)
5. **Renomeie** para: `HF Mesa Hand & Foot`
6. **Description**: deixe vazio

> 💡 **Dica**: Use um cilindro com 32-64 lados para bordas suaves. Aplique textura de madeira nas laterais (faces 1-4) e feltro no topo (face 0).

### Passo 2.2 — Assentos (4 child prims)

Para cada assento (Norte=0, Leste=1, Sul=2, Oeste=3):

1. **Build → Create → Box** (cubo pequeno, 0.5×0.5×0.1)
2. Posição: ao redor da mesa, a ~1.2m do centro
   - Norte: `<0, -1.2, 0.5>` | Leste: `<1.2, 0, 0.5>` | Sul: `<0, 1.2, 0.5>` | Oeste: `<-1.2, 0, 0.5>`
3. Textura: madeira ou tecido (opcional)
4. Cor: diferenciar times (Time 1 = azul, Time 2 = vermelho)
5. **Description**: número do assento (`0`, `1`, `2` ou `3`)
6. **Renomeie** para: `HF Assento N` (N = 0-3)
7. **Vincule** ao prim raiz (selecione todos + raiz por último → Ctrl+L)

### Passo 2.3 — Placar (1 child prim)

1. **Build → Create → Box** (plano fino, 1.0×0.5×0.01)
2. Posição: acima da mesa, `<0, 0, 1.5>`
3. Cor: preto ou transparente
4. **Renomeie** para: `HF Placar`

### Passo 2.4 — Pilha de Compra (Stock) (1 child prim)

1. **Build → Create → Box** (fino, 0.15×0.15×0.3 — formato carta)
2. Posição: centro da mesa deslocado, `<-0.5, 0, 0.15>`
3. Textura: verso de carta (`card_back.png`)
4. **Renomeie** para: `HF Stock`

### Passo 2.5 — Pilha de Descarte (1 child prim)

1. **Build → Create → Box** (fino, 0.15×0.15×0.3)
2. Posição: `<0.5, 0, 0.15>`
3. Textura: verso de carta (será atualizado pelo script)
4. **Renomeie** para: `HF Descarte`

### Passo 2.6 — Foot de cada jogador (4 child prims, opcional)

Para cada jogador, um prim representando o foot:

1. **Build → Create → Box** (0.15×0.15×0.3)
2. Posição: próximo ao assento correspondente
3. Textura: verso de carta
4. **Renomeie** para: `HF Foot N` (N = 0-3)

### Passo 2.7 — Melds dos Times (2 child prims)

1. **Build → Create → Box** (plano, 1.0×0.5×0.01)
2. Posição: de cada lado da mesa
   - Time 1: `<0, -0.8, 0.1>` | Time 2: `<0, 0.8, 0.1>`
3. Cor: semitransparente
4. **Renomeie** para: `HF Melds Time 1` e `HF Melds Time 2`

### Passo 2.8 — Vincular tudo

1. Selecione todos os child prims
2. Selecione o prim raiz **por último** (ele será o link root)
3. **Ctrl+L** (Link)
4. Verifique: o prim raiz deve ter borda amarela (indica root link)

> 💡 **Dica**: Para verificar a ordem dos links, use **Build → Path → Show Link Set**. O root é sempre link 0.

---

## FASE 3: Criar Objetos no Inventário

### Passo 3.1 — Objeto "HF Card" (template de carta)

Este objeto será rezzado pela mesa para cada carta visível.

1. **Build → Create → Box**
2. Tamanho: `<0.10, 0.07, 0.15>` (formato carta, ~10cm × 15cm)
3. Textura face 0 (topo): verso de carta (padrão)
4. Textura face 1 (baixo): verso de carta
5. **Renomeie** para: `HF Card`
6. Abra o conteúdo → **New Script** → cole o conteúdo de `lsl/HF_Card.lsl`
7. Salve o script
8. **Take** o objeto para o inventário

### Passo 3.2 — Objeto "HF HUD" (HUD do jogador)

1. **Build → Create → Box** (pequeno, 0.05×0.05×0.05)
2. **Renomeie** para: `HF HUD`
3. Abra o conteúdo → **New Script** → cole o conteúdo de `lsl/HF_HUD.lsl`
4. Salve o script
5. **Take** o objeto para o inventário

> ⚠️ O HUD será entregue ao jogador quando sentar. Ele deve **attach** o objeto ao HUD Center ou outro ponto HUD.

---

## FASE 4: Adicionar Scripts e Conteúdo

### Passo 4.1 — Script do Motor (no prim raiz)

1. Selecione a mesa (prim raiz)
2. Abra o conteúdo (Build → Edit → Content tab)
3. **New Script** → renomeie para `HF_Engine`
4. Abra o script → cole o conteúdo de `lsl/HF_Engine.lsl`
5. **Save** (Ctrl+S)

> ⚠️ Se der erro de compilação, verifique se não há caracteres especiais (acentos) no script. O LSL não suporta Unicode.

### Passo 4.2 — Scripts dos Assentos

Para cada prim de assento:

1. Selecione o assento
2. Abra o conteúdo → **New Script** → renomeie para `HF_Seat`
3. Cole o conteúdo de `lsl/HF_Seat.lsl`
4. **Save**

### Passo 4.3 — Script do Placar

1. Selecione o prim do placar
2. Abra o conteúdo → **New Script** → renomeie para `HF_Scoreboard`
3. Cole o conteúdo de `lsl/HF_Scoreboard.lsl`
4. **Save**

### Passo 4.4 — Notecard de Configuração

1. Selecione a mesa (prim raiz)
2. Abra o conteúdo → **New Notecard** → renomeie para `HF Config`
3. Cole o conteúdo de `notecards/HF_Config.txt` (com UUIDs preenchidos!)
4. **Save**

### Passo 4.5 — Notecard de Regras

1. Na mesa, conteúdo → **New Notecard** → renomeie para `HF Regras`
2. Cole o conteúdo de `notecards/HF_Regras.txt`
3. **Save**

### Passo 4.6 — Objetos no inventário da mesa

1. Na mesa, conteúdo → **Drop** o objeto `HF Card` do seu inventário
2. Na mesa, conteúdo → **Drop** o objeto `HF HUD` do seu inventário

> A mesa precisa ter esses objetos no inventário para rezzar cartas e entregar HUDs.

---

## FASE 5: Configurar Permissões

### Passo 5.1 — Permissões do objeto

1. Selecione a mesa (link set inteiro)
2. **Build → Edit → General tab**
3. Marque: ✅ **Allow anyone to move** (opcional, para reposicionar)
4. Marque: ✅ **Allow anyone to copy** (opcional, se quiser vender cópias)

### Passo 5.2 — Permissões dos scripts

1. Na mesa, conteúdo → clique com botão direito em cada script
2. **Properties** → marque:
   - ✅ **Modify** (para o owner poder editar)
   - ✅ **Copy** (para poder fazer backups)
   - ❌ **Transfer** (se não quiser que outros vejam o código)

---

## FASE 6: Testar

### Passo 6.1 — Teste básico (1 jogador)

1. Vá para uma **sandbox** (ex: sandbox a, b, c em DanielHaven)
2. Rez a mesa no chão
3. **Sente-se** em um dos assentos
4. Verifique: você deve receber o HUD no inventário
5. **Attach** o HUD (clique com botão direito → Attach → HUD Center)
6. No chat local, diga: **`/1start`** (ou toque na mesa para o menu)
7. Verifique: cartas devem aparecer no HUD (floating text)
8. Teste: toque no HUD → menu "Comprar 2"
9. Teste: toque no HUD → menu "Descartar" → selecione uma carta

### Passo 6.2 — Teste com 2+ jogadores

1. Chame amigos ou use alts
2. Cada jogador senta em um assento
3. Cada jogador attach o HUD recebido
4. O owner diz: `/1start`
5. Jogue algumas rodadas para testar:
   - Compra do stock
   - Meld (3+ cartas do mesmo rank)
   - Descarte
   - Pegar foot
   - Sair (go out)

### Passo 6.3 — Teste de pontuação

1. Jogue uma rodada completa até alguém sair
2. Verifique os pontos no placar
3. Compare com a tabela de pontuação nas regras

---

## FASE 7: Personalização (Opcional)

### 7.1 — Alterar número de baralhos

Edite `HF Config`:
```
NUM_DECKS=5    # 5 baralhos = 270 cartas (mais comum em alguns grupos)
```

### 7.2 — Alterar pontuação de livros

```
CLEAN_BOOK=300   # Versão mais conservadora
DIRTY_BOOK=100
```

### 7.3 — Alterar mínimo para baixar

```
MIN_MELD=50,90,120    # 3 rodadas em vez de 4
```

### 7.4 — Suporte a 2 ou 3 jogadores

O motor suporta 2-4 jogadores. Para menos de 4:
- Deixe os assentos vazios
- O jogo funciona com 2+ jogadores (sem times se ímpar)

### 7.5 — Cores e aparência

- Assentos: diferenciar por time (azul/vermelho)
- Mesa: personalize a textura de feltro
- HUD: edite o script para mudar cores do floating text

---

## 🔧 Solução de Problemas

### "Não é sua vez ou fase incorreta"
- Verifique se é seu turno (o placar mostra o jogador atual)
- Aguarde sua vez

### "Pontos insuficientes para baixar"
- Seu primeiro meld deve atingir o mínimo da rodada (50/90/120/150)
- Tente incluir cartas de alto valor (A=20, 8-K=10)

### HUD não recebe cartas
- Verifique se o HUD está **attached** (não apenas no inventário)
- Toque no HUD → "Atualizar" para requisitar estado
- Verifique se o canal está correto (HUD e mesa devem estar na mesma região)

### Cartas não aparecem na mesa
- Verifique se `HF Card` está no inventário da mesa
- Verifique se as UUIDs das texturas estão corretas no notecard

### Script não compila
- Verifique se não há caracteres acentuados (LSL = ASCII)
- Use o verificador: `python3 tools/check_lsl.py`

---

## 📐 Layout Visual da Mesa

```
           [Assento 0 - Norte]
                (Time 1)
                   │
     [Melds T1]   │   [Melds T2]
                   │
 [Oeste]────[STOCK] [DESC]────[Leste]
 (Time 2)      │          │    (Time 1)
               │          │
           [  PLACAR  ]
               │
           [Assento 2 - Sul]
                (Time 2)
```

---

## 🎨 Atlas de Texturas — Referência

As cartas usam 2 atlas de 1024×1024 com grade 8×4 (cada célula 128×256):

**Atlas 1** (faceCode 0-31):
| Row | Col 0 | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 | Col 6 | Col 7 |
|-----|-------|-------|-------|-------|-------|-------|-------|-------|
| 0   | 3♣    | 3♦    | 3♥    | 3♠    | 4♣    | 4♦    | 4♥    | 4♠    |
| 1   | 5♣    | 5♦    | 5♥    | 5♠    | 6♣    | 6♦    | 6♥    | 6♠    |
| 2   | 7♣    | 7♦    | 7♥    | 7♠    | 8♣    | 8♦    | 8♥    | 8♠    |
| 3   | 9♣    | 9♦    | 9♥    | 9♠    | 10♣   | 10♦   | 10♥   | 10♠   |

**Atlas 2** (faceCode 32-53):
| Row | Col 0 | Col 1 | Col 2 | Col 3 | Col 4 | Col 5 | Col 6 | Col 7 |
|-----|-------|-------|-------|-------|-------|-------|-------|-------|
| 0   | J♣    | J♦    | J♥    | J♠    | Q♣    | Q♦    | Q♥    | Q♠    |
| 1   | K♣    | K♦    | K♥    | K♠    | A♣    | A♦    | A♥    | A♠    |
| 2   | 2♣    | 2♦    | 2♥    | 2♠    | JkV   | JkP   | —     | —     |
| 3   | —     | —     | —     | —     | —     | —     | —     | —     |

**Offsets por célula:**
- Horizontal repeat: `0.125` (1/8)
- Vertical repeat: `0.25` (1/4)
- Horizontal offset: `col × 0.125`
- Vertical offset: `1.0 - (row + 1) × 0.25`

---

## ✅ Checklist Final

- [ ] Texturas uploadeadas (4 PNGs, L$40)
- [ ] UUIDs copiados para o notecard `HF Config`
- [ ] Mesa construída (1 root + 4 assentos + placar + stock + descarte)
- [ ] Todos os prims linkados (root = mesa)
- [ ] Script `HF_Engine.lsl` no prim raiz
- [ ] Script `HF_Seat.lsl` em cada assento (description = 0-3)
- [ ] Script `HF_Scoreboard.lsl` no placar
- [ ] Notecard `HF Config` no inventário da mesa
- [ ] Notecard `HF Regras` no inventário da mesa
- [ ] Objeto `HF Card` no inventário da mesa (com script HF_Card.lsl)
- [ ] Objeto `HF HUD` no inventário da mesa (com script HF_HUD.lsl)
- [ ] Testado em sandbox com 2+ jogadores
- [ ] Pontuação verificada

---

## 🚀 Próximos Passos (Melhorias Futuras)

1. **Animação de distribuição** — cartas voando do stock para cada jogador
2. **Straights (sequências)** — suporte opcional a runs do mesmo naipe
3. **Salvar/Carregar jogo** — persistir estado via notecard ou HTTP
4. **Sons** — baralho, carta virada, meld, go out
5. **Partículas** — efeito ao completar um livro (canasta)
6. **Texturas 3D** — cartas com profundidade e sombra
7. **Multi-mesa** — suporte a várias mesas na mesma região
8. **Estatísticas** — tracking de vitórias/derrotas por jogador
9. **Suporte a 6+ jogadores** — times de 3 ou individual
10. **Marketplace** — empacotar para venda com permissões corretas

---

*Projeto original — Hand & Foot Canasta para Second Life*
*Regras de domínio público • Código LSL aberto e modificável*
