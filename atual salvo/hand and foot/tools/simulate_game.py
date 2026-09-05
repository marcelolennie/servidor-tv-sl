#!/usr/bin/env python3
"""
Simulador de Hand & Foot Canasta — motor de regras em Python.

Espelha a lógica do script LSL (HF_Engine.lsl) para validar:
- Embaralhamento e distribuição
- Validação de melds
- Pontuação (livros limpos/sujos, bônus, penalidades)
- Condições de saída (go out)
- Fluxo completo de uma partida com jogadas aleatórias

Uso: python3 tools/simulate_game.py [--rounds N] [--verbose]
"""

import random, sys, argparse
from collections import defaultdict

# ═══════════════════════════════════════════════════════════════
# CONSTANTES (espelhadas no LSL)
# ═══════════════════════════════════════════════════════════════
NUM_DECKS = 4          # 4 baralhos de 54 cartas
CARDS_PER_DECK = 54
TOTAL_CARDS = NUM_DECKS * CARDS_PER_DECK  # 216
HAND_SIZE = 11
FOOT_SIZE = 11
NUM_PLAYERS = 4
NUM_TEAMS = 2

# Ranks: 3=3, 4=4,...,10=10, J=11, Q=12, K=13, A=14, 2=15 (wild), Joker=16
RANK_3, RANK_7, RANK_2, RANK_JOKER = 3, 7, 15, 16
RANK_NAMES = {3:'3',4:'4',5:'5',6:'6',7:'7',8:'8',9:'9',10:'10',
              11:'J',12:'Q',13:'K',14:'A',15:'2',16:'Jk'}
SUIT_NAMES = {0:'♣', 1:'♦', 2:'♥', 3:'♠'}

# Pontos por valor de carta
CARD_POINTS = {}
for r in range(3, 8):   CARD_POINTS[r] = 5    # 3-7
for r in range(8, 14):  CARD_POINTS[r] = 10   # 8-K
CARD_POINTS[14] = 20     # A
CARD_POINTS[15] = 20     # 2 (wild)
CARD_POINTS[16] = 50     # Joker

# Naipes vermelhos: ouros(1), copas(2)
RED_SUITS = {1, 2}

# Bônus
CLEAN_BOOK_BONUS = 500
DIRTY_BOOK_BONUS = 300
RED_3_BONUS = 100
RED_3_PENALTY = -100   # se sobrar no foot
GO_OUT_BONUS = 100

# Mínimo para baixar (por rodada, índice 0-based)
MIN_MELD_LADDER = [50, 90, 120, 150]
NUM_ROUNDS = 4

# ═══════════════════════════════════════════════════════════════
# CARTA
# ═══════════════════════════════════════════════════════════════
class Card:
    """Representa uma carta única no baralho."""
    _next_uid = 0

    def __init__(self, rank, suit, deck_idx):
        self.uid = Card._next_uid
        Card._next_uid += 1
        self.rank = rank       # 3-14 normal, 15=2(wild), 16=Joker
        self.suit = suit       # 0-3 para cartas normais e 2s; -1 para jokers
        self.deck_idx = deck_idx

    @property
    def is_wild(self):
        return self.rank >= 15   # 2s e Jokers

    @property
    def is_red_3(self):
        return self.rank == 3 and self.suit in RED_SUITS

    @property
    def is_black_3(self):
        return self.rank == 3 and self.suit not in RED_SUITS

    @property
    def points(self):
        if self.is_red_3:
            return RED_3_BONUS
        return CARD_POINTS.get(self.rank, 0)

    @property
    def meld_points(self):
        """Pontos para contagem do mínimo de meld (red 3s não contam)."""
        if self.is_red_3:
            return 0
        return CARD_POINTS.get(self.rank, 0)

    def __repr__(self):
        if self.rank == 16:
            return f"Jk{'V' if self.suit==1 else 'P'}[{self.uid}]"
        r = RANK_NAMES.get(self.rank, '?')
        s = SUIT_NAMES.get(self.suit, '?')
        return f"{r}{s}[{self.uid}]"

    def short(self):
        if self.rank == 16:
            return "JkV" if self.suit == 1 else "JkP"
        return RANK_NAMES.get(self.rank,'?') + SUIT_NAMES.get(self.suit,'?')


# ═══════════════════════════════════════════════════════════════
# MELD (livro/melda)
# ═══════════════════════════════════════════════════════════════
class Meld:
    """Um meld (conjunto de cartas do mesmo rank)."""
    def __init__(self, rank):
        self.rank = rank
        self.natural_cards = []   # cartas naturais
        self.wild_cards = []      # cartas wild (2s, jokers)

    @property
    def total(self):
        return len(self.natural_cards) + len(self.wild_cards)

    @property
    def is_clean(self):
        return len(self.wild_cards) == 0

    @property
    def is_book(self):
        return self.total >= 7

    @property
    def is_clean_book(self):
        return self.is_book and self.is_clean

    @property
    def is_dirty_book(self):
        return self.is_book and not self.is_clean

    def can_add_natural(self, card):
        """Verifica se uma carta natural pode ser adicionada."""
        if card.rank != self.rank:
            return False
        if card.is_wild:
            return False
        # Black 3s: só em meld de black 3s sem wilds
        if card.is_black_3 and len(self.wild_cards) > 0:
            return False
        return True

    def can_add_wild(self, card):
        """Verifica se uma carta wild pode ser adicionada."""
        if not card.is_wild:
            return False
        # Não pode adicionar wild a meld de black 3s
        if self.rank == 3 and all(c.is_black_3 for c in self.natural_cards):
            return False
        # Máximo: mais naturais que wilds → wilds < naturais
        if len(self.wild_cards) + 1 > len(self.natural_cards):
            return False
        return True

    def add_card(self, card):
        if card.is_wild:
            self.wild_cards.append(card)
        else:
            self.natural_cards.append(card)

    def score(self):
        """Pontuação do livro (bônus), sem pontos das cartas individuais."""
        if not self.is_book:
            return 0
        if self.is_clean_book:
            # Livro limpo de 2s ou Jokers = 2000
            if self.rank == 15 and len(self.natural_cards) >= 7:
                return 2000
            if self.rank == 16 and len(self.natural_cards) >= 7:
                return 2000
            return CLEAN_BOOK_BONUS
        else:
            # Livro sujo de wilds mistos (2s + jokers) = 1000
            if self.rank >= 15 and len(self.natural_cards) == 0:
                return 1000
            return DIRTY_BOOK_BONUS

    def card_values_sum(self):
        """Soma dos valores das cartas no meld (para contagem final)."""
        total = 0
        for c in self.natural_cards:
            total += CARD_POINTS.get(c.rank, 0)
        for c in self.wild_cards:
            total += CARD_POINTS.get(c.rank, 0)
        return total

    def __repr__(self):
        kind = "LIMPO" if self.is_clean else "SUJO"
        book = " ★LIVRO" if self.is_book else ""
        return f"Meld({RANK_NAMES.get(self.rank,'?')}, N={len(self.natural_cards)}, W={len(self.wild_cards)}, {kind}{book})"


# ═══════════════════════════════════════════════════════════════
# JOGADOR
# ═══════════════════════════════════════════════════════════════
class Player:
    def __init__(self, idx, name, team):
        self.idx = idx
        self.name = name
        self.team = team          # 0 ou 1
        self.hand = []            # cartas na mão
        self.foot = []            # cartas no foot
        self.is_down = False      # já baixou (fez meld inicial)
        self.in_foot = False      # jogando do foot
        self.red_3s_laid = 0      # red 3s laid down

    @property
    def current_cards(self):
        return self.foot if self.in_foot else self.hand

    def hand_value(self):
        """Soma dos valores das cartas restantes na mão+foot (penalidade)."""
        total = 0
        for c in self.hand:
            total += CARD_POINTS.get(c.rank, 0)
        for c in self.foot:
            v = CARD_POINTS.get(c.rank, 0)
            # Red 3s no foot: penalidade extra
            if c.is_red_3:
                total += abs(RED_3_PENALTY)  # já contou 100, precisa somar penalidade
            total += v if not c.is_red_3 else 0
        return total


# ═══════════════════════════════════════════════════════════════
# TIME
# ═══════════════════════════════════════════════════════════════
class Team:
    def __init__(self, idx):
        self.idx = idx
        self.melds = {}          # rank → Meld
        self.score = 0           # score acumulado
        self.is_down = False     # time já baixou

    def get_or_create_meld(self, rank):
        if rank not in self.melds:
            self.melds[rank] = Meld(rank)
        return self.melds[rank]

    def has_clean_book(self):
        return any(m.is_clean_book for m in self.melds.values())

    def has_dirty_book(self):
        return any(m.is_dirty_book for m in self.melds.values())

    def round_score(self, players, count_cards=True):
        """Calcula pontuação da rodada para este time."""
        total = 0
        # Bônus de livros
        for m in self.melds.values():
            total += m.score()
            if count_cards:
                total += m.card_values_sum()
        # Red 3s laid
        for p in players:
            if p.team == self.idx:
                total += p.red_3s_laid * RED_3_BONUS
        # Going out bonus (será adicionado externamente)
        # Penalidade: cartas na mão/foot
        for p in players:
            if p.team == self.idx:
                for c in p.hand + p.foot:
                    total -= CARD_POINTS.get(c.rank, 0)
                    if c.is_red_3:
                        total += RED_3_PENALTY  # -100 extra
        return total


# ═══════════════════════════════════════════════════════════════
# JOGO
# ═══════════════════════════════════════════════════════════════
class HandAndFootGame:
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.players = []
        self.teams = [Team(0), Team(1)]
        self.stock = []          # pilha de compra
        self.discard = []        # pilha de descarte
        self.round_num = 0       # 0-based
        self.current_player = 0
        self.turn_phase = 'draw' # draw, meld, discard
        self.game_over = False
        self.round_scores = []

        # Criar jogadores (2 times de 2)
        names = ["Norte", "Leste", "Sul", "Oeste"]
        for i in range(NUM_PLAYERS):
            team = 0 if i % 2 == 0 else 1
            self.players.append(Player(i, names[i], team))

    def log(self, msg):
        if self.verbose:
            print(msg)

    # ── Baralho e distribuição ────────────────────────────────
    def create_deck(self):
        """Cria e embaralha o baralho completo."""
        Card._next_uid = 0
        all_cards = []
        for deck in range(NUM_DECKS):
            # Cartas normais: ranks 3-14 (3 a A), 4 naipes
            for rank in range(3, 15):
                for suit in range(4):
                    all_cards.append(Card(rank, suit, deck))
            # Dois (wild): rank 15, 4 naipes
            for suit in range(4):
                all_cards.append(Card(15, suit, deck))
            # Jokers: rank 16, suit 0 (preto) e 1 (vermelho)
            all_cards.append(Card(16, 0, deck))  # Joker preto
            all_cards.append(Card(16, 1, deck))  # Joker vermelho

        assert len(all_cards) == TOTAL_CARDS, f"Esperado {TOTAL_CARDS}, obtido {len(all_cards)}"
        random.shuffle(all_cards)
        return all_cards

    def deal(self):
        """Distribui mãos e feet, monta stock e descarte."""
        all_cards = self.create_deck()
        idx = 0
        for p in self.players:
            p.hand = all_cards[idx:idx+HAND_SIZE]
            idx += HAND_SIZE
            p.foot = all_cards[idx:idx+FOOT_SIZE]
            idx += FOOT_SIZE
            p.is_down = False
            p.in_foot = False
            p.red_3s_laid = 0

        self.stock = all_cards[idx:]
        # Virar primeira carta do stock como descarte inicial
        # (garantir que não seja wild ou red 3)
        while self.stock:
            card = self.stock.pop()
            if not card.is_wild and not card.is_red_3:
                self.discard = [card]
                break
            else:
                self.stock.insert(0, card)  # devolver ao fundo
                # Se todas forem wild/red3, usar a última mesmo
                if len(self.stock) < 2:
                    self.discard = [self.stock.pop()]
                    break

        for t in self.teams:
            t.melds = {}
            t.is_down = False

        self.log(f"\n{'='*60}")
        self.log(f"RODADA {self.round_num+1} — Mínimo para baixar: {self.min_meld_required()}")
        self.log(f"Stock: {len(self.stock)} cartas | Descarte: {len(self.discard)} cartas")
        for p in self.players:
            self.log(f"  {p.name} (Time {p.team+1}): Mão={len(p.hand)} Foot={len(p.foot)}")

    def min_meld_required(self):
        """Mínimo de pontos para o primeiro meld da rodada."""
        idx = min(self.round_num, len(MIN_MELD_LADDER)-1)
        return MIN_MELD_LADDER[idx]

    # ── Ações do jogador ──────────────────────────────────────
    def draw_from_stock(self, player):
        """Compra 2 cartas do stock."""
        drawn = []
        for _ in range(2):
            if self.stock:
                c = self.stock.pop()
                player.current_cards.append(c)
                drawn.append(c)
        self.log(f"  {player.name} comprou: {', '.join(c.short() for c in drawn)}")
        return drawn

    def take_top_discard(self, player):
        """Pega o topo do descarte + 1 do stock (turno de abertura)."""
        if not self.discard:
            return []
        card = self.discard.pop()
        player.current_cards.append(card)
        drawn = [card]
        if self.stock:
            c = self.stock.pop()
            player.current_cards.append(c)
            drawn.append(c)
        self.log(f"  {player.name} pegou descarte+stock: {', '.join(c.short() for c in drawn)}")
        return drawn

    def take_discard_pile(self, player):
        """Pega toda a pilha de descarte (deve meldar o topo imediatamente)."""
        if not self.discard:
            return []
        cards = self.discard[:]
        self.discard = []
        player.current_cards.extend(cards)
        self.log(f"  {player.name} pegou pilha de descarte ({len(cards)} cartas)")
        return cards

    def can_take_discard_pile(self, player):
        """Verifica se o jogador pode pegar a pilha de descarte."""
        if not self.discard:
            return False
        top = self.discard[-1]
        if top.is_wild or top.is_black_3:
            return False  # não pode pegar se topo é wild ou black 3
        team = self.teams[player.team]
        # Verificar se tem meld existente do mesmo rank
        if top.rank in team.melds:
            meld = team.melds[top.rank]
            if meld.can_add_natural(top):
                return True
        # Verificar se tem 2 cartas naturais do mesmo rank na mão
        matching = [c for c in player.current_cards if c.rank == top.rank and not c.is_wild]
        if len(matching) >= 2:
            return True
        return False

    def discard_card(self, player, card):
        """Descarta uma carta."""
        cards = player.current_cards
        if card in cards:
            cards.remove(card)
            self.discard.append(card)
            self.log(f"  {player.name} descartou: {card.short()}")
            return True
        return False

    def try_meld(self, player, cards_to_meld):
        """Tenta criar um meld com as cartas dadas. Retorna True se sucesso."""
        if len(cards_to_meld) < 3:
            return False

        # Determinar rank do meld
        naturals = [c for c in cards_to_meld if not c.is_wild]
        wilds = [c for c in cards_to_meld if c.is_wild]

        if not naturals and wilds:
            # Meld de puros wilds (2s e/ou jokers)
            rank = 15  # rank "wild"
        elif naturals:
            rank = naturals[0].rank
            # Verificar se todas as naturais são do mesmo rank
            for c in naturals:
                if c.rank != rank:
                    return False
        else:
            return False

        # Black 3s: só grupos de black 3s, sem wilds
        if rank == 3:
            if wilds:
                return False
            if any(c.is_red_3 for c in naturals):
                return False  # red 3s não podem ser meldados

        # Red 3s: não podem ser meldados
        if any(c.is_red_3 for c in cards_to_meld):
            return False

        # Validar wilds: máximo = naturais - 1 (mais naturais que wilds)
        if wilds and naturals:
            if len(wilds) > len(naturals):
                return False

        # Mínimo 2 naturais (exceto meld de puros wilds)
        if rank < 15 and len(naturals) < 2:
            return False

        team = self.teams[player.team]

        # Verificar meld existente
        if rank in team.melds:
            meld = team.melds[rank]
            for c in naturals:
                if not meld.can_add_natural(c):
                    return False
            for c in wilds:
                if not meld.can_add_wild(c):
                    return False
        else:
            # Novo meld: mínimo 3 cartas
            if len(cards_to_meld) < 3:
                return False

        # Verificar mínimo para baixar (primeira vez)
        if not team.is_down:
            # Calcular pontos totais dos melds que serão baixados nesta rodada
            meld_points = sum(c.meld_points for c in cards_to_meld)
            existing_points = sum(m.card_values_sum() for m in team.melds.values())
            if existing_points + meld_points < self.min_meld_required():
                return False

        # Executar meld
        meld = team.get_or_create_meld(rank)
        for c in cards_to_meld:
            meld.add_card(c)
            if c in player.current_cards:
                player.current_cards.remove(c)

        team.is_down = True
        player.is_down = True

        self.log(f"  {player.name} meldou: {meld}")
        return True

    def add_to_meld(self, player, meld_rank, card):
        """Adiciona uma carta a um meld existente do time."""
        team = self.teams[player.team]
        if meld_rank not in team.melds:
            return False
        meld = team.melds[meld_rank]
        if card.is_wild:
            if not meld.can_add_wild(card):
                return False
        else:
            if not meld.can_add_natural(card):
                return False
        meld.add_card(card)
        player.current_cards.remove(card)
        self.log(f"  {player.name} adicionou {card.short()} ao meld de {RANK_NAMES.get(meld_rank,'?')} → {meld}")
        return True

    def can_go_out(self, player):
        """Verifica se o jogador/time pode sair (go out)."""
        team = self.teams[player.team]
        # Precisa de pelo menos 1 livro limpo e 1 livro sujo
        if not team.has_clean_book() or not team.has_dirty_book():
            return False
        # Precisa ter mão e foot vazios (ou só 1 carta para descartar)
        total_cards = len(player.hand) + len(player.foot)
        return total_cards <= 1  # pode descartar a última

    def check_pickup_foot(self, player):
        """Se a mão está vazia e ainda não está no foot, pega o foot."""
        if not player.in_foot and len(player.hand) == 0 and len(player.foot) > 0:
            player.in_foot = True
            self.log(f"  {player.name} pegou o FOOT! ({len(player.foot)} cartas)")
            return True
        return False

    def lay_red_3s(self, player):
        """Automaticamente baixa red 3s e compra reposição."""
        laid = 0
        cards = player.current_cards
        to_lay = [c for c in cards if c.is_red_3]
        for c in to_lay:
            cards.remove(c)
            player.red_3s_laid += 1
            laid += 1
            # Comprar reposição do stock
            if self.stock:
                cards.append(self.stock.pop())
        if laid:
            self.log(f"  {player.name} baixou {laid} red 3(s) e reposicionou")
        return laid

    # ── Simulação de jogada aleatória ──────────────────────────
    def random_play_turn(self, player):
        """Simula uma jogada aleatória para o jogador (simplificada)."""
        self.log(f"\n--- Turno de {player.name} (Time {player.team+1}) ---")
        self.log(f"  Cartas: {', '.join(c.short() for c in player.current_cards)}")

        # 1. Baixar red 3s automaticamente
        self.lay_red_3s(player)

        # 2. Comprar
        if self.discard and random.random() < 0.2 and self.can_take_discard_pile(player):
            self.take_discard_pile(player)
        elif self.discard and random.random() < 0.1:
            self.take_top_discard(player)
        else:
            self.draw_from_stock(player)

        # Baixar red 3s das cartas compradas
        self.lay_red_3s(player)

        # 3. Tentar meld (simplificado: tentar criar melds de 3+ cartas do mesmo rank)
        team = self.teams[player.team]
        if not team.is_down or random.random() < 0.7:
            self._try_auto_meld(player)

        # 4. Verificar se pode pegar foot
        self.check_pickup_foot(player)

        # 5. Descartar (se tiver cartas)
        if player.current_cards:
            # Não descartar wild se possível
            non_wild = [c for c in player.current_cards if not c.is_wild]
            to_discard = non_wild[0] if non_wild else player.current_cards[0]
            self.discard_card(player, to_discard)

        # Verificar foot novamente após descarte
        self.check_pickup_foot(player)

    def _try_auto_meld(self, player):
        """Tenta automaticamente criar melds com as cartas na mão."""
        cards = player.current_cards[:]
        # Agrupar por rank
        by_rank = defaultdict(list)
        for c in cards:
            if not c.is_wild and not c.is_red_3:
                by_rank[c.rank].append(c)

        wilds = [c for c in cards if c.is_wild]

        # Tentar melds de 3+ naturais do mesmo rank
        for rank, rank_cards in sorted(by_rank.items()):
            if rank == 3:  # black 3s só se going out
                continue
            team = self.teams[player.team]
            if rank in team.melds:
                # Adicionar a meld existente
                meld = team.melds[rank]
                for c in rank_cards:
                    if meld.can_add_natural(c) and c in player.current_cards:
                        self.add_to_meld(player, rank, c)
                # Adicionar wilds se possível
                for c in wilds[:]:
                    if meld.can_add_wild(c) and c in player.current_cards:
                        self.add_to_meld(player, rank, c)
                        wilds.remove(c)
            elif len(rank_cards) >= 3:
                # Criar novo meld
                meld_cards = rank_cards[:3]
                # Adicionar wild se disponível e rank != 3
                if wilds and rank != 3:
                    meld_cards.append(wilds[0])
                    wilds = wilds[1:]
                self.try_meld(player, meld_cards)

        # Tentar meld de wilds puros (se 3+ wilds)
        if len(wilds) >= 3:
            team = self.teams[player.team]
            if 15 not in team.melds:
                self.try_meld(player, wilds[:3])

    # ── Pontuação da rodada ────────────────────────────────────
    def score_round(self, going_out_team):
        """Calcula e retorna pontuação da rodada."""
        scores = {}
        for t in self.teams:
            rs = t.round_score(self.players, count_cards=True)
            if t.idx == going_out_team:
                rs += GO_OUT_BONUS
            t.score += rs
            scores[t.idx] = rs
            self.log(f"  Time {t.idx+1}: +{rs} pontos (total: {t.score})")
        return scores

    # ── Partida completa ───────────────────────────────────────
    def play_round(self):
        """Joga uma rodada completa."""
        self.deal()
        self.current_player = 0
        turns = 0
        max_turns = 500  # safety

        while turns < max_turns:
            player = self.players[self.current_player]

            # Verificar se stock vazio → fim da rodada
            if not self.stock and not self.discard:
                self.log("\n  Stock e descarte vazios — fim da rodada!")
                going_out_team = -1
                self.score_round(going_out_team)
                return

            self.random_play_turn(player)
            turns += 1

            # Verificar going out
            if self.can_go_out(player):
                self.log(f"\n  ★ {player.name} SAIU (GO OUT)! ★")
                self.score_round(player.team)
                return

            # Próximo jogador
            self.current_player = (self.current_player + 1) % NUM_PLAYERS

        self.log(f"\n  Rodada encerrada após {max_turns} turnos (limite de segurança)")
        self.score_round(-1)

    def play_game(self, num_rounds=None):
        """Joga uma partida completa."""
        if num_rounds is None:
            num_rounds = NUM_ROUNDS

        print(f"\n{'#'*60}")
        print(f"# HAND & FOOT CANASTA — Simulação")
        print(f"# {NUM_PLAYERS} jogadores, {NUM_TEAMS} times, {NUM_DECKS} baralhos")
        print(f"# {num_rounds} rodadas")
        print(f"{'#'*60}")

        for r in range(num_rounds):
            self.round_num = r
            self.play_round()

        print(f"\n{'='*60}")
        print(f"RESULTADO FINAL")
        print(f"{'='*60}")
        for t in self.teams:
            print(f"  Time {t.idx+1}: {t.score} pontos")
            print(f"    Livros limpos: {sum(1 for m in t.melds.values() if m.is_clean_book)}")
            print(f"    Livros sujos: {sum(1 for m in t.melds.values() if m.is_dirty_book)}")

        winner = 0 if self.teams[0].score > self.teams[1].score else 1
        print(f"\n  ★ VENCEDOR: Time {winner+1} ★")
        return self.teams[0].score, self.teams[1].score


# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Simulador Hand & Foot Canasta')
    parser.add_argument('--rounds', type=int, default=4, help='Número de rodadas')
    parser.add_argument('--verbose', '-v', action='store_true', help='Saída detalhada')
    parser.add_argument('--games', type=int, default=1, help='Número de partidas para simular')
    args = parser.parse_args()

    for g in range(args.games):
        game = HandAndFootGame(verbose=args.verbose)
        s0, s1 = game.play_game(num_rounds=args.rounds)
        if args.games > 1:
            print(f"  Jogo {g+1}: Time 1={s0}, Time 2={s1}")

    print("\n✅ Simulação concluída com sucesso!")
