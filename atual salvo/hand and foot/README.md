# 🃏 Hand & Foot Canasta — Mesa para Second Life

Projeto completo para criar sua própria mesa de **Hand and Foot Canasta** no Second Life, com motor de jogo, HUD dos jogadores, placar, texturas de cartas e guia passo a passo.

---

## 📋 O que está incluído

| Arquivo | Descrição |
|---------|-----------|
| `lsl/HF_Engine.lsl` | Motor principal do jogo (prim raiz da mesa) |
| `lsl/HF_HUD.lsl` | HUD do jogador (attachment) |
| `lsl/HF_Card.lsl` | Script de cada carta rezzada |
| `lsl/HF_Seat.lsl` | Script dos assentos |
| `lsl/HF_Scoreboard.lsl` | Placar flutuante |
| `notecards/HF_Config.txt` | Configuração (baralhos, pontuação, UUIDs de textura) |
| `notecards/HF_Regras.txt` | Regras do jogo (notecard in-world) |
| `assets/cards_atlas_1.png` | Atlas de texturas — cartas 3♣ a 10♠ |
| `assets/cards_atlas_2.png` | Atlas de texturas — cartas J♣ a Joker |
| `assets/card_back.png` | Verso das cartas |
| `assets/table_felt.png` | Textura de feltro verde para a mesa |
| `tools/make_card_atlas.py` | Gerador de atlas de cartas (Python + Pillow) |
| `tools/simulate_game.py` | Simulador/validador de regras (Python) |
| `tools/check_lsl.py` | Verificador de sintaxe LSL |

---

## ⚡ Resumo Rápido

1. **Upload texturas** → 4 PNGs no SL (L$10 cada)
2. **Construir a mesa** → 1 prim raiz (cilindro) + 4 assentos + placar + pilhas
3. **Adicionar scripts** → Engine no raiz, Seat nos assentos, Scoreboard no placar
4. **Configurar notecard** → Colar UUIDs das texturas no `HF Config`
5. **Criar HUD** → Box prim com HF_HUD.lsl, colocar no inventário da mesa
6. **Criar carta template** → Box fino com HF_Card.lsl, colocar no inventário da mesa
7. **Testar** → Sentar, receber HUD, iniciar jogo com `/1start`

---

## 🎮 Regras Implementadas

- **4 jogadores** em 2 times (parceiros sentam frente a frente)
- **4 baralhos** de 54 cartas (216 total), configurável
- **11 cartas** na Mão + **11 cartas** no Foot por jogador
- **Red 3s** baixados automaticamente (+100 pts cada)
- **Wilds**: Curingas (50 pts) e Dois (20 pts)
- **Livro Limpo** (7 naturais) = +500 | **Livro Sujo** (com wilds) = +300
- **Mínimo para baixar**: Rodada 1=50, 2=90, 3=120, 4=150
- **Sair (Go Out)**: requer 1 livro limpo + 1 livro sujo, +100 bônus
- **Pegar descarte**: topo + 1 do stock, ou pilha inteira (se pode meldar)
- Tudo configurável via notecard `HF Config`

---

## 🛠️ Ferramentas de Desenvolvimento

### Gerar atlas de cartas
```bash
pip install Pillow
python3 tools/make_card_atlas.py
# → Gera assets/cards_atlas_1.png, cards_atlas_2.png, card_back.png
```

### Simular partida (validar regras)
```bash
python3 tools/simulate_game.py --rounds 4 --games 5 --verbose
```

### Verificar sintaxe LSL
```bash
python3 tools/check_lsl.py
```

---

## 📖 Guia Completo

Para instruções detalhadas de construção no Second Life, consulte:

👉 **[GUIA-PASSO-A-PASSO.md](GUIA-PASSO-A-PASSO.md)** — Passo a passo completo com screenshots e dicas

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────┐
│           MESA (Root Prim)              │
│         HF_Engine.lsl                   │
│                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐│
│  │Seat 0│  │Seat 1│  │Seat 2│  │Seat 3││
│  │ Norte│  │ Leste│  │  Sul │  │Oeste ││
│  └──────┘  └──────┘  └──────┘  └──────┘│
│                                         │
│     ┌──────────┐   ┌────┐  ┌────┐      │
│     │Scoreboard│   │Stock│  │Disc│      │
│     └──────────┘   └────┘  └────┘      │
└─────────────────────────────────────────┘

    Jogador (Avatar)
    └── HUD Attachment (HF_HUD.lsl)
        ├── Floating text: mão + status
        └── Dialog menus: ações do jogo
```

**Comunicação:**
- Engine ↔ HUD: `llRegionSay` / `llRegionSayTo` em canais derivados da key
- Engine ↔ Child prims: `llMessageLinked` (link messages)
- HUD → Engine: `llRegionSay` no canal base

---

## ⚠️ Notas Importantes

- Este é um projeto **original** escrito do zero — não é cópia de nenhum produto do Marketplace
- As regras de Hand & Foot Canasta são de domínio público (regras de jogos não têm copyright)
- O código LSL é aberto e modificável — personalize à vontade
- Texturas de cartas são geradas por código (Pillow) — sem assets de terceiros
- Teste sempre em uma **sandbox** antes de usar in-world

---

## 📜 Licença

Código LSL e scripts Python: uso livre para criação de sua mesa no Second Life.
As regras de Hand & Foot Canasta são de domínio público.
