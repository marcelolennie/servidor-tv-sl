// ═══════════════════════════════════════════════════════════════════════════════
// HF_Engine.lsl — Motor principal do Hand & Foot Canasta (Second Life)
// Colocar no prim RAIZ da mesa.
//
// Arquitetura:
//   - Este script gerencia TODO o estado do jogo (baralho, mãos, melds, pontos)
//   - Comunica-se com HUDs dos jogadores via llRegionSayTo em canais privados
//   - Comunica-se com prims filhos (assentos, placar, pilhas) via link messages
//   - Lê configuração do notecard "HF Config"
//
// Versão: 1.0.0
// ═══════════════════════════════════════════════════════════════════════════════

// ── Constantes ──────────────────────────────────────────────────────────────────
integer NUM_DECKS      = 4;       // Número de baralhos (54 cartas cada)
integer HAND_SIZE      = 11;      // Cartas na mão
integer FOOT_SIZE      = 11;      // Cartas no foot
integer NUM_PLAYERS    = 4;       // Jogadores (2 times de 2)
integer NUM_ROUNDS     = 4;       // Rodadas por partida

// Pontuação
integer CLEAN_BOOK     = 500;     // Livro limpo (canasta natural)
integer DIRTY_BOOK     = 300;     // Livro sujo (canasta com wild)
integer RED3_BONUS     = 100;     // Red 3 laid
integer RED3_PENALTY   = -100;    // Red 3 left in foot
integer GO_OUT_BONUS   = 100;     // Bônus por sair

// Mínimo para baixar por rodada (índice 0-based)
list MIN_MELD_LADDER  = [50, 90, 120, 150];

// Ranks (espelhados do Python)
// 3=3, 4=4,...,10=10, J=11, Q=12, K=13, A=14, 2=15(wild), Joker=16
integer RANK_3  = 3;
integer RANK_7  = 7;
integer RANK_2  = 15;    // Wild
integer RANK_JK = 16;    // Joker

// Naipes: 0=♣, 1=♦, 2=♥, 3=♠
// Red: 1(♦), 2(♥)

// Pontos por rank (para valor de carta)
// Usado como lookup: index = rank-3, valor em CARD_PTS
list CARD_PTS = [5,5,5,5,5,10,10,10,10,10,10,20,  // 3-A (ranks 3-14)
                 20,                                   // 2 (rank 15)
                 50];                                  // Joker (rank 16)

// ── Canais ──────────────────────────────────────────────────────────────────────
integer gBaseChan;      // Canal base (derivado da key do objeto)
integer gListenHandle;  // Handle do listen principal

// ── Estado do jogo ──────────────────────────────────────────────────────────────
integer gRoundNum;          // Rodada atual (0-based)
integer gCurrentPlayer;     // Jogador atual (0-3)
string  gTurnPhase;         // "draw", "meld", "discard"
integer gGameActive;        // Jogo em andamento?
integer gRoundActive;       // Rodada em andamento?

// Jogadores: [key, name, team, isDown, inFoot, red3sLaid, handStr, footStr]
// handStr/footStr: lista de cardUids separada por ","
list gPlayers;              // Strided list: 8 stride

// Times: [isDown, score, meldsStr]
// meldsStr: "rank:natCount:wildCount|rank:natCount:wildCount|..."
list gTeams;                // Strided list: 3 stride

// Baralho
list gStock;                // Lista de cardUids (integers)
list gDiscard;              // Lista de cardUids

// Contador de UIDs
integer gNextUid;

// Config notecard
key     gConfigNCKey;
integer gConfigLine;
string  gConfigName = "HF Config";

// Texturas (UUIDs lidos do notecard)
string  gAtlas1UUID;
string  gAtlas2UUID;
string  gCardBackUUID;

// ── Funções auxiliares ──────────────────────────────────────────────────────────

// Decodificar uid → faceCode
integer uid2face(integer uid) {
    return uid % 54;
}

// Decodificar faceCode → rank
integer face2rank(integer fc) {
    if (fc < 48) return (fc / 4) + 3;
    if (fc < 52) return 15;     // 2 (wild)
    return 16;                   // Joker
}

// Decodificar faceCode → suit (0-3)
integer face2suit(integer fc) {
    if (fc < 52) return fc % 4;
    return 0;  // Jokers: suit 0 (preto) ou 1 (vermelho)
}

// Verificar se é wild (2 ou Joker)
integer isWild(integer fc) {
    integer r = face2rank(fc);
    return (r >= 15);
}

// Verificar se é red 3
integer isRed3(integer fc) {
    return (face2rank(fc) == 3) && (face2suit(fc) == 1 || face2suit(fc) == 2);
}

// Verificar se é black 3
integer isBlack3(integer fc) {
    return (face2rank(fc) == 3) && (face2suit(fc) != 1 && face2suit(fc) != 2);
}

// Pontos de uma carta por rank
integer cardPoints(integer rank) {
    integer idx = rank - 3;
    if (idx < 0 || idx > 13) return 0;
    return llList2Integer(CARD_PTS, idx);
}

// Nome curto da carta (para display)
string cardShort(integer uid) {
    integer fc = uid2face(uid);
    integer r = face2rank(fc);
    integer s = face2suit(fc);
    string rs;
    if (r <= 10)      rs = (string)r;
    else if (r == 11) rs = "J";
    else if (r == 12) rs = "Q";
    else if (r == 13) rs = "K";
    else if (r == 14) rs = "A";
    else if (r == 15) rs = "2";
    else              rs = "Jk";
    string ss;
    if (r == 16) {
        ss = "V"; if (s == 0) ss = "P";
    } else {
        if (s == 0) ss = "♣";
        else if (s == 1) ss = "♦";
        else if (s == 2) ss = "♥";
        else ss = "♠";
    }
    return rs + ss;
}

// Rank name
string rankName(integer r) {
    if (r <= 10)      return (string)r;
    if (r == 11) return "J";
    if (r == 12) return "Q";
    if (r == 13) return "K";
    if (r == 14) return "A";
    if (r == 15) return "2";
    return "Jk";
}

// Mínimo para baixar nesta rodada
integer minMeldRequired() {
    integer idx = gRoundNum;
    if (idx >= llGetListLength(MIN_MELD_LADDER)) idx = llGetListLength(MIN_MELD_LADDER) - 1;
    return llList2Integer(MIN_MELD_LADDER, idx);
}

// Channel derivado da key
integer calcBaseChan() {
    return -0x7FF00000 + (integer)("0x" + llGetSubString((string)llGetKey(), 0, 6));
}

// Player channel
integer playerChan(integer idx) {
    return gBaseChan + idx + 1;
}

// ── Parsing de listas de cartas (string CSV → list of integers) ────────────────
list parseCards(string s) {
    if (s == "") return [];
    list parts = llCSV2List(s);
    list result;
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        result += [(integer)llStringTrim(llList2String(parts, i), STRING_TRIM)];
    }
    return result;
}

string packCards(list cards) {
    return llList2CSV(cards);
}

// ── Player accessors (stride 8) ────────────────────────────────────────────────
key     playerKey(integer i)    { return llList2Key(gPlayers, i*8); }
string  playerName(integer i)   { return llList2String(gPlayers, i*8+1); }
integer playerTeam(integer i)   { return llList2Integer(gPlayers, i*8+2); }
integer playerIsDown(integer i) { return llList2Integer(gPlayers, i*8+3); }
integer playerInFoot(integer i) { return llList2Integer(gPlayers, i*8+4); }
integer playerRed3s(integer i)  { return llList2Integer(gPlayers, i*8+5); }
list    playerHand(integer i)   { return parseCards(llList2String(gPlayers, i*8+6)); }
list    playerFoot(integer i)   { return parseCards(llList2String(gPlayers, i*8+7)); }

setPlayer(integer i, key k, string n, integer t, integer d, integer f, integer r3, string h, string ft) {
    gPlayers = llListReplaceList(gPlayers, [k, n, t, d, f, r3, h, ft], i*8, i*8+7);
}

setPlayerHand(integer i, list h) {
    gPlayers = llListReplaceList(gPlayers, [packCards(h)], i*8+6, i*8+6);
}

setPlayerFoot(integer i, list f) {
    gPlayers = llListReplaceList(gPlayers, [packCards(f)], i*8+7, i*8+7);
}

setPlayerIsDown(integer i, integer v) {
    gPlayers = llListReplaceList(gPlayers, [v], i*8+3, i*8+3);
}

setPlayerInFoot(integer i, integer v) {
    gPlayers = llListReplaceList(gPlayers, [v], i*8+4, i*8+4);
}

setPlayerRed3s(integer i, integer v) {
    gPlayers = llListReplaceList(gPlayers, [v], i*8+5, i*8+5);
}

// ── Team accessors (stride 3) ──────────────────────────────────────────────────
integer teamIsDown(integer i)  { return llList2Integer(gTeams, i*3); }
integer teamScore(integer i)  { return llList2Integer(gTeams, i*3+1); }
string  teamMelds(integer i)  { return llList2String(gTeams, i*3+2); }

setTeam(integer i, integer d, integer s, string m) {
    gTeams = llListReplaceList(gTeams, [d, s, m], i*3, i*3+2);
}

setTeamIsDown(integer i, integer v) {
    gTeams = llListReplaceList(gTeams, [v], i*3, i*3);
}

setTeamScore(integer i, integer v) {
    gTeams = llListReplaceList(gTeams, [v], i*3+1, i*3+1);
}

setTeamMelds(integer i, string m) {
    gTeams = llListReplaceList(gTeams, [m], i*3+2, i*3+2);
}

// ── Melds: string "rank:nat:wild|rank:nat:wild|..." ────────────────────────────
// Encontrar meld de um rank no time
list findMeld(integer teamIdx, integer rank) {
    string ms = teamMelds(teamIdx);
    list parts = llParseString2List(ms, ["|"], []);
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        list entry = llParseString2List(llList2String(parts, i), [":"], []);
        if (llList2Integer(entry, 0) == rank) {
            return entry;  // [rank, natCount, wildCount]
        }
    }
    return [];
}

// Adicionar/atualizar meld
updateMeld(integer teamIdx, integer rank, integer natCount, integer wildCount) {
    string ms = teamMelds(teamIdx);
    list parts = llParseString2List(ms, ["|"], []);
    list newParts;
    integer found = FALSE;
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        list entry = llParseString2List(llList2String(parts, i), [":"], []);
        if (llList2Integer(entry, 0) == rank) {
            newParts += [rank + ":" + natCount + ":" + wildCount];
            found = TRUE;
        } else {
            newParts += [llList2String(parts, i)];
        }
    }
    if (!found) {
        newParts += [rank + ":" + natCount + ":" + wildCount];
    }
    setTeamMelds(teamIdx, llDumpList2String(newParts, "|"));
}

// Verificar se time tem livro limpo
integer teamHasCleanBook(integer teamIdx) {
    string ms = teamMelds(teamIdx);
    list parts = llParseString2List(ms, ["|"], []);
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        list e = llParseString2List(llList2String(parts, i), [":"], []);
        integer nat = llList2Integer(e, 1);
        integer wild = llList2Integer(e, 2);
        if (nat + wild >= 7 && wild == 0) return TRUE;
    }
    return FALSE;
}

// Verificar se time tem livro sujo
integer teamHasDirtyBook(integer teamIdx) {
    string ms = teamMelds(teamIdx);
    list parts = llParseString2List(ms, ["|"], []);
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        list e = llParseString2List(llList2String(parts, i), [":"], []);
        integer nat = llList2Integer(e, 1);
        integer wild = llList2Integer(e, 2);
        if (nat + wild >= 7 && wild > 0) return TRUE;
    }
    return FALSE;
}

// ── Embaralhamento (Fisher-Yates) ──────────────────────────────────────────────
list shuffleList(list l) {
    integer n = llGetListLength(l);
    integer i;
    for (i = n - 1; i > 0; i--) {
        integer j = (integer)llFrand(i + 1);
        // Swap i and j
        integer vi = llList2Integer(l, i);
        integer vj = llList2Integer(l, j);
        l = llListReplaceList(l, [vj], i, i);
        l = llListReplaceList(l, [vi], j, j);
    }
    return l;
}

// ── Criar e embaralhar baralho ─────────────────────────────────────────────────
list createDeck() {
    list deck;
    integer d;
    for (d = 0; d < NUM_DECKS; d++) {
        // Ranks 3-14 (3 a A), 4 naipes → faceCodes 0-47
        integer fc;
        for (fc = 0; fc < 48; fc++) {
            deck += [gNextUid * 54 + fc];  // uid = deckIdx*54 + faceCode? No.
            // Actually: uid = gNextUid++
        }
        // 2s: faceCodes 48-51
        for (fc = 48; fc < 52; fc++) {
            deck += [gNextUid++];
        }
        // Jokers: faceCodes 52-53
        deck += [gNextUid++];
        deck += [gNextUid++];
    }
    // Wait, the uid calculation above is wrong. Let me fix:
    // uid should just be a unique sequential integer.
    // faceCode = uid % 54
    // deckIdx = uid / 54
    // So I need to assign uids sequentially.
    // Let me redo:
    deck = [];
    gNextUid = 0;
    for (d = 0; d < NUM_DECKS; d++) {
        integer fc;
        for (fc = 0; fc < 54; fc++) {
            deck += [gNextUid];
            gNextUid++;
        }
    }
    return shuffleList(deck);
}

// ── Comunicação com HUD ────────────────────────────────────────────────────────
sendToHUD(integer playerIdx, string msg) {
    key k = playerKey(playerIdx);
    if (k != NULL_KEY) {
        llRegionSayTo(k, playerChan(playerIdx), msg);
    }
}

broadcastToHUDs(string msg) {
    integer i;
    for (i = 0; i < NUM_PLAYERS; i++) {
        sendToHUD(i, msg);
    }
}

// Enviar hand para HUD
sendHandToHUD(integer playerIdx) {
    list hand;
    if (playerInFoot(playerIdx)) {
        hand = playerFoot(playerIdx);
    } else {
        hand = playerHand(playerIdx);
    }
    // Formato: HAND|uid1:short1,uid2:short2,...
    string msg = "HAND|";
    list parts;
    integer i;
    for (i = 0; i < llGetListLength(hand); i++) {
        integer uid = llList2Integer(hand, i);
        parts += [(string)uid + ":" + cardShort(uid)];
    }
    msg += llDumpList2String(parts, ",");
    sendToHUD(playerIdx, msg);
}

// Enviar estado do jogo para todos
sendGameState() {
    // Formato: STATE|round|currentPlayer|phase|stockCount|discardCount|discardTop|minMeld
    string dt = "";
    if (llGetListLength(gDiscard) > 0) {
        dt = cardShort(llList2Integer(gDiscard, llGetListLength(gDiscard) - 1));
    }
    string msg = "STATE|" + (string)(gRoundNum+1) + "|" + (string)gCurrentPlayer + "|" +
                 gTurnPhase + "|" + (string)llGetListLength(gStock) + "|" +
                 (string)llGetListLength(gDiscard) + "|" + dt + "|" + (string)minMeldRequired();
    broadcastToHUDs(msg);

    // Enviar melds de cada time
    integer t;
    for (t = 0; t < 2; t++) {
        string meldMsg = "MELDS|" + (string)t + "|" + teamMelds(t);
        broadcastToHUDs(meldMsg);
    }

    // Enviar scores
    string scoreMsg = "SCORE|" + (string)teamScore(0) + "|" + (string)teamScore(1);
    broadcastToHUDs(scoreMsg);
}

// ── Atualizar display (placar, pilhas) via link messages ───────────────────────
updateDisplays() {
    // Link message para scoreboard: LM_UPDATE_SCORE
    llMessageLinked(LINK_ALL_CHILDREN, 100, (string)teamScore(0) + "|" + (string)teamScore(1), "");

    // Link message para piles: LM_UPDATE_PILES
    string topDiscard = "";
    if (llGetListLength(gDiscard) > 0) {
        topDiscard = (string)llList2Integer(gDiscard, llGetListLength(gDiscard) - 1);
    }
    llMessageLinked(LINK_ALL_CHILDREN, 101,
        (string)llGetListLength(gStock) + "|" + (string)llGetListLength(gDiscard) + "|" + topDiscard, "");

    // Atualizar floating text nos assentos
    integer i;
    for (i = 0; i < NUM_PLAYERS; i++) {
        string name = playerName(i);
        if (name == "") name = "(vazio)";
        string info = name;
        if (playerIsDown(i)) info += " ✓";
        if (playerInFoot(i)) info += " [FOOT]";
        llMessageLinked(LINK_ALL_CHILDREN, 102 + i, info, "");
    }
}

// ── Distribuição ────────────────────────────────────────────────────────────────
dealRound() {
    list deck = createDeck();
    integer idx = 0;
    integer i;

    // Distribuir mãos e feet
    for (i = 0; i < NUM_PLAYERS; i++) {
        list hand = llList2List(deck, idx, idx + HAND_SIZE - 1);
        idx += HAND_SIZE;
        list foot = llList2List(deck, idx, idx + FOOT_SIZE - 1);
        idx += FOOT_SIZE;

        setPlayerHand(i, hand);
        setPlayerFoot(i, foot);
        setPlayerIsDown(i, FALSE);
        setPlayerInFoot(i, FALSE);
        setPlayerRed3s(i, 0);
    }

    // Stock = resto
    gStock = llList2List(deck, idx, -1);

    // Virar primeira carta não-wild/não-red3 para descarte
    gDiscard = [];
    while (llGetListLength(gStock) > 0) {
        integer card = llList2Integer(gStock, llGetListLength(gStock) - 1);
        integer fc = uid2face(card);
        if (!isWild(fc) && !isRed3(fc)) {
            gDiscard = [card];
            gStock = llList2List(gStock, 0, llGetListLength(gStock) - 2);
            jump break_discard;
        }
        // Mover para o fundo do stock
        gStock = [card] + llList2List(gStock, 0, llGetListLength(gStock) - 2);
    }
    @break_discard;

    // Resetar melds dos times
    integer t;
    for (t = 0; t < 2; t++) {
        setTeamIsDown(t, FALSE);
        setTeamMelds(t, "");
    }

    gCurrentPlayer = 0;
    gTurnPhase = "draw";
    gRoundActive = TRUE;

    // Notificar HUDs
    for (i = 0; i < NUM_PLAYERS; i++) {
        sendHandToHUD(i);
    }
    sendGameState();
    updateDisplays();

    llOwnerSay("Rodada " + (string)(gRoundNum+1) + " distribuída. Mínimo para baixar: " + (string)minMeldRequired());
}

// ── Processar ações do HUD ─────────────────────────────────────────────────────
processDraw(integer playerIdx) {
    if (playerIdx != gCurrentPlayer || gTurnPhase != "draw") {
        sendToHUD(playerIdx, "ERROR|Não é sua vez ou fase incorreta");
        return;
    }

    // Comprar 2 do stock
    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    integer drawn = 0;
    while (drawn < 2 && llGetListLength(gStock) > 0) {
        integer card = llList2Integer(gStock, llGetListLength(gStock) - 1);
        gStock = llList2List(gStock, 0, llGetListLength(gStock) - 2);
        hand += [card];
        drawn++;
    }

    if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, hand);
    else setPlayerHand(playerIdx, hand);

    gTurnPhase = "meld";

    // Auto-lay red 3s
    layRed3s(playerIdx);

    sendHandToHUD(playerIdx);
    sendGameState();
    updateDisplays();
}

processTakeDiscard(integer playerIdx) {
    if (playerIdx != gCurrentPlayer || gTurnPhase != "draw") {
        sendToHUD(playerIdx, "ERROR|Não é sua vez ou fase incorreta");
        return;
    }
    if (llGetListLength(gDiscard) == 0) {
        sendToHUD(playerIdx, "ERROR|Pilha de descarte vazia");
        return;
    }

    // Pegar topo do descarte + 1 do stock
    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    integer topCard = llList2Integer(gDiscard, llGetListLength(gDiscard) - 1);
    gDiscard = llList2List(gDiscard, 0, llGetListLength(gDiscard) - 2);
    hand += [topCard];

    if (llGetListLength(gStock) > 0) {
        integer sc = llList2Integer(gStock, llGetListLength(gStock) - 1);
        gStock = llList2List(gStock, 0, llGetListLength(gStock) - 2);
        hand += [sc];
    }

    if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, hand);
    else setPlayerHand(playerIdx, hand);

    gTurnPhase = "meld";
    layRed3s(playerIdx);

    sendHandToHUD(playerIdx);
    sendGameState();
    updateDisplays();
}

processTakePile(integer playerIdx) {
    if (playerIdx != gCurrentPlayer || gTurnPhase != "draw") {
        sendToHUD(playerIdx, "ERROR|Não é sua vez ou fase incorreta");
        return;
    }
    if (llGetListLength(gDiscard) == 0) {
        sendToHUD(playerIdx, "ERROR|Pilha de descarte vazia");
        return;
    }

    // Verificar se pode pegar a pilha
    integer topCard = llList2Integer(gDiscard, llGetListLength(gDiscard) - 1);
    integer topFc = uid2face(topCard);

    if (isWild(topFc) || isBlack3(topFc)) {
        sendToHUD(playerIdx, "ERROR|Topo da pilha é wild ou 3 preto");
        return;
    }

    integer topRank = face2rank(topFc);
    integer teamIdx = playerTeam(playerIdx);

    // Verificar meld existente ou 2 naturais na mão
    list existingMeld = findMeld(teamIdx, topRank);
    integer canTake = FALSE;

    if (llGetListLength(existingMeld) > 0) {
        canTake = TRUE;
    } else {
        list hand;
        if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
        else hand = playerHand(playerIdx);
        integer matchingNaturals = 0;
        integer i;
        for (i = 0; i < llGetListLength(hand); i++) {
            integer uid = llList2Integer(hand, i);
            integer fc = uid2face(uid);
            if (face2rank(fc) == topRank && !isWild(fc)) matchingNaturals++;
        }
        if (matchingNaturals >= 2) canTake = TRUE;
    }

    if (!canTake) {
        sendToHUD(playerIdx, "ERROR|Não pode pegar a pilha — precisa de 2 naturais ou meld existente");
        return;
    }

    // Pegar toda a pilha
    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    hand += gDiscard;
    gDiscard = [];

    if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, hand);
    else setPlayerHand(playerIdx, hand);

    gTurnPhase = "meld";
    layRed3s(playerIdx);

    sendHandToHUD(playerIdx);
    sendGameState();
    updateDisplays();
}

// Meld: criar novo meld ou adicionar a existente
processMeld(integer playerIdx, list cardUids) {
    if (playerIdx != gCurrentPlayer || (gTurnPhase != "meld" && gTurnPhase != "draw")) {
        sendToHUD(playerIdx, "ERROR|Não é sua vez ou fase incorreta para meld");
        return;
    }
    if (llGetListLength(cardUids) < 3) {
        sendToHUD(playerIdx, "ERROR|Meld precisa de pelo menos 3 cartas");
        return;
    }

    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    // Verificar que todas as cartas estão na mão
    integer i;
    for (i = 0; i < llGetListLength(cardUids); i++) {
        integer uid = llList2Integer(cardUids, i);
        if (llListFindList(hand, [uid]) == -1) {
            sendToHUD(playerIdx, "ERROR|Carta " + (string)uid + " não está na sua mão");
            return;
        }
    }

    // Classificar cartas
    list naturals;
    list wilds;
    for (i = 0; i < llGetListLength(cardUids); i++) {
        integer uid = llList2Integer(cardUids, i);
        if (isWild(uid2face(uid))) wilds += [uid];
        else naturals += [uid];
    }

    // Determinar rank
    integer meldRank;
    if (llGetListLength(naturals) == 0 && llGetListLength(wilds) > 0) {
        meldRank = 15;  // Meld de wilds puros
    } else if (llGetListLength(naturals) > 0) {
        meldRank = face2rank(uid2face(llList2Integer(naturals, 0)));
        // Verificar todas naturais mesmo rank
        for (i = 1; i < llGetListLength(naturals); i++) {
            if (face2rank(uid2face(llList2Integer(naturals, i))) != meldRank) {
                sendToHUD(playerIdx, "ERROR|Cartas naturais de ranks diferentes");
                return;
            }
        }
    } else {
        sendToHUD(playerIdx, "ERROR|Meld vazio");
        return;
    }

    // Red 3s não podem ser meldados
    for (i = 0; i < llGetListLength(naturals); i++) {
        if (isRed3(uid2face(llList2Integer(naturals, i)))) {
            sendToHUD(playerIdx, "ERROR|Red 3s não podem ser meldados");
            return;
        }
    }

    // Black 3s: sem wilds
    if (meldRank == 3 && llGetListLength(wilds) > 0) {
        sendToHUD(playerIdx, "ERROR|Black 3s não aceitam wilds");
        return;
    }

    // Wilds limit: mais naturais que wilds
    if (llGetListLength(wilds) > 0 && llGetListLength(naturals) > 0) {
        if (llGetListLength(wilds) > llGetListLength(naturals)) {
            sendToHUD(playerIdx, "ERROR|Muitos wilds — precisa de mais naturais que wilds");
            return;
        }
    }

    // Mínimo 2 naturais (exceto meld de wilds puros)
    if (meldRank < 15 && llGetListLength(naturals) < 2) {
        sendToHUD(playerIdx, "ERROR|Meld precisa de pelo menos 2 cartas naturais");
        return;
    }

    integer teamIdx = playerTeam(playerIdx);

    // Verificar mínimo para baixar (primeira vez do time)
    if (!teamIsDown(teamIdx)) {
        integer meldPts = 0;
        for (i = 0; i < llGetListLength(cardUids); i++) {
            integer uid = llList2Integer(cardUids, i);
            integer fc = uid2face(uid);
            if (!isRed3(fc)) {
                meldPts += cardPoints(face2rank(fc));
            }
        }
        // Somar pontos de melds existentes
        string ms = teamMelds(teamIdx);
        list parts = llParseString2List(ms, ["|"], []);
        integer existingPts = 0;
        integer j;
        for (j = 0; j < llGetListLength(parts); j++) {
            list e = llParseString2List(llList2String(parts, j), [":"], []);
            integer r = llList2Integer(e, 0);
            integer n = llList2Integer(e, 1);
            integer w = llList2Integer(e, 2);
            existingPts += n * cardPoints(r) + w * cardPoints(15);  // Simplificado
        }
        if (existingPts + meldPts < minMeldRequired()) {
            sendToHUD(playerIdx, "ERROR|Pontos insuficientes para baixar (precisa " + (string)minMeldRequired() + ", tem " + (string)(existingPts + meldPts) + ")");
            return;
        }
    }

    // Verificar meld existente
    list existingMeld = findMeld(teamIdx, meldRank);
    integer natCount = llGetListLength(naturals);
    integer wildCount = llGetListLength(wilds);

    if (llGetListLength(existingMeld) > 0) {
        // Adicionar a meld existente
        integer existNat = llList2Integer(existingMeld, 1);
        integer existWild = llList2Integer(existingMeld, 2);

        // Verificar wild limit
        if (existWild + wildCount > existNat + natCount) {
            sendToHUD(playerIdx, "ERROR|Muitos wilds no meld existente");
            return;
        }

        updateMeld(teamIdx, meldRank, existNat + natCount, existWild + wildCount);
    } else {
        // Novo meld
        updateMeld(teamIdx, meldRank, natCount, wildCount);
    }

    // Remover cartas da mão
    for (i = 0; i < llGetListLength(cardUids); i++) {
        integer uid = llList2Integer(cardUids, i);
        integer pos = llListFindList(hand, [uid]);
        if (pos != -1) {
            hand = llListReplaceList(hand, [], pos, pos);
        }
    }

    if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, hand);
    else setPlayerHand(playerIdx, hand);

    setPlayerIsDown(playerIdx, TRUE);
    setTeamIsDown(teamIdx, TRUE);

    // Verificar foot pickup
    checkFootPickup(playerIdx);

    sendHandToHUD(playerIdx);
    sendGameState();
    updateDisplays();
}

// Descartar
processDiscard(integer playerIdx, integer cardUid) {
    if (playerIdx != gCurrentPlayer) {
        sendToHUD(playerIdx, "ERROR|Não é sua vez");
        return;
    }
    if (gTurnPhase != "meld" && gTurnPhase != "draw") {
        sendToHUD(playerIdx, "ERROR|Fase incorreta para descarte");
        return;
    }

    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    integer pos = llListFindList(hand, [cardUid]);
    if (pos == -1) {
        sendToHUD(playerIdx, "ERROR|Carta não encontrada na mão");
        return;
    }

    // Remover da mão e adicionar ao descarte
    hand = llListReplaceList(hand, [], pos, pos);
    gDiscard += [cardUid];

    if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, hand);
    else setPlayerHand(playerIdx, hand);

    // Verificar foot pickup
    checkFootPickup(playerIdx);

    // Verificar going out
    if (canGoOut(playerIdx)) {
        endRound(playerIdx);
        return;
    }

    // Próximo jogador
    nextTurn();
}

// Auto-lay red 3s
layRed3s(integer playerIdx) {
    list hand;
    if (playerInFoot(playerIdx)) hand = playerFoot(playerIdx);
    else hand = playerHand(playerIdx);

    integer laid = 0;
    list newHand;
    integer i;
    for (i = 0; i < llGetListLength(hand); i++) {
        integer uid = llList2Integer(hand, i);
        if (isRed3(uid2face(uid))) {
            laid++;
            // Comprar reposição
            if (llGetListLength(gStock) > 0) {
                integer rep = llList2Integer(gStock, llGetListLength(gStock) - 1);
                gStock = llList2List(gStock, 0, llGetListLength(gStock) - 2);
                newHand += [rep];
            }
        } else {
            newHand += [uid];
        }
    }

    if (laid > 0) {
        setPlayerRed3s(playerIdx, playerRed3s(playerIdx) + laid);
        if (playerInFoot(playerIdx)) setPlayerFoot(playerIdx, newHand);
        else setPlayerHand(playerIdx, newHand);
        sendToHUD(playerIdx, "INFO|Red 3(s) baixado(s) automaticamente: " + (string)laid);
    }
}

// Verificar foot pickup
checkFootPickup(integer playerIdx) {
    if (!playerInFoot(playerIdx) && llGetListLength(playerHand(playerIdx)) == 0 && llGetListLength(playerFoot(playerIdx)) > 0) {
        setPlayerInFoot(playerIdx, TRUE);
        sendToHUD(playerIdx, "INFO|Você pegou o FOOT!");
        sendHandToHUD(playerIdx);
    }
}

// Verificar going out
integer canGoOut(integer playerIdx) {
    integer teamIdx = playerTeam(playerIdx);
    if (!teamHasCleanBook(teamIdx) || !teamHasDirtyBook(teamIdx)) return FALSE;

    list hand = playerHand(playerIdx);
    list foot = playerFoot(playerIdx);
    // Mão e foot devem estar vazios (após descarte da última carta)
    if (llGetListLength(hand) + llGetListLength(foot) == 0) return TRUE;
    return FALSE;
}

// Pontuação da rodada
calculateRoundScore(integer teamIdx, integer goingOutTeam) {
    integer total = 0;

    // Bônus de livros
    string ms = teamMelds(teamIdx);
    list parts = llParseString2List(ms, ["|"], []);
    integer i;
    for (i = 0; i < llGetListLength(parts); i++) {
        list e = llParseString2List(llList2String(parts, i), [":"], []);
        integer r = llList2Integer(e, 0);
        integer nat = llList2Integer(e, 1);
        integer wild = llList2Integer(e, 2);
        integer count = nat + wild;

        if (count >= 7) {
            if (wild == 0) {
                // Livro limpo
                if (r >= 15) total += 2000;  // Wild puro
                else total += CLEAN_BOOK;
            } else {
                if (r >= 15 && nat == 0) total += 1000;  // Wild misto
                else total += DIRTY_BOOK;
            }
        }

        // Valor das cartas no meld
        total += nat * cardPoints(r);
        if (r >= 15) total += wild * cardPoints(r);
        else total += wild * cardPoints(15);  // Wilds valem 20/50
    }

    // Red 3s laid
    integer j;
    for (j = 0; j < NUM_PLAYERS; j++) {
        if (playerTeam(j) == teamIdx) {
            total += playerRed3s(j) * RED3_BONUS;
        }
    }

    // Going out bonus
    if (teamIdx == goingOutTeam) total += GO_OUT_BONUS;

    // Penalidade: cartas na mão/foot
    for (j = 0; j < NUM_PLAYERS; j++) {
        if (playerTeam(j) == teamIdx) {
            list h = playerHand(j);
            list f = playerFoot(j);
            integer k;
            for (k = 0; k < llGetListLength(h); k++) {
                integer uid = llList2Integer(h, k);
                total -= cardPoints(face2rank(uid2face(uid)));
                if (isRed3(uid2face(uid))) total += RED3_PENALTY;
            }
            for (k = 0; k < llGetListLength(f); k++) {
                integer uid = llList2Integer(f, k);
                total -= cardPoints(face2rank(uid2face(uid)));
                if (isRed3(uid2face(uid))) total += RED3_PENALTY;
            }
        }
    }

    return total;
}

// Finalizar rodada
endRound(integer goingOutPlayer) {
    integer goingOutTeam = playerTeam(goingOutPlayer);

    integer t;
    for (t = 0; t < 2; t++) {
        integer rs = calculateRoundScore(t, goingOutTeam);
        setTeamScore(t, teamScore(t) + rs);
    }

    gRoundActive = FALSE;

    // Notificar todos
    string msg = "ROUND_END|" + (string)(gRoundNum+1) + "|" +
                 (string)teamScore(0) + "|" + (string)teamScore(1);
    broadcastToHUDs(msg);

    sendGameState();
    updateDisplays();

    llOwnerSay("Rodada " + (string)(gRoundNum+1) + " finalizada! Time 1: " +
               (string)teamScore(0) + " | Time 2: " + (string)teamScore(1));

    // Verificar fim de jogo
    if (gRoundNum + 1 >= NUM_ROUNDS) {
        gGameActive = FALSE;
        string winner;
        if (teamScore(0) > teamScore(1)) winner = "Time 1";
        else if (teamScore(1) > teamScore(0)) winner = "Time 2";
        else winner = "Empate";
        llOwnerSay("FIM DE JOGO! Vencedor: " + winner);
        broadcastToHUDs("GAME_OVER|" + (string)teamScore(0) + "|" + (string)teamScore(1) + "|" + winner);
    }
}

// Próximo turno
nextTurn() {
    gCurrentPlayer = (gCurrentPlayer + 1) % NUM_PLAYERS;
    gTurnPhase = "draw";

    // Verificar stock vazio
    if (llGetListLength(gStock) == 0 && llGetListLength(gDiscard) == 0) {
        endRound(-1);
        return;
    }

    sendHandToHUD(gCurrentPlayer);
    sendGameState();
    updateDisplays();
}

// ── Registro de jogadores ──────────────────────────────────────────────────────
integer findPlayerSlot(key avatarKey) {
    integer i;
    for (i = 0; i < NUM_PLAYERS; i++) {
        if (playerKey(i) == avatarKey) return i;
    }
    return -1;
}

integer findEmptySlot() {
    integer i;
    for (i = 0; i < NUM_PLAYERS; i++) {
        if (playerKey(i) == NULL_KEY) return i;
    }
    return -1;
}

registerPlayer(key avatarKey, string name) {
    integer slot = findPlayerSlot(avatarKey);
    if (slot != -1) {
        sendToHUD(slot, "INFO|Você já está registrado no assento " + (string)(slot+1));
        return;
    }
    slot = findEmptySlot();
    if (slot == -1) {
        llRegionSayTo(avatarKey, 0, "Todos os assentos estão ocupados!");
        return;
    }

    integer team = slot % 2;  // 0 ou 1 (alternado)
    setPlayer(slot, avatarKey, name, team, FALSE, FALSE, 0, "", "");

    llRegionSayTo(avatarKey, 0, "Registrado no assento " + (string)(slot+1) + " (Time " + (string)(team+1) + ")");
    sendToHUD(slot, "WELCOME|" + (string)slot + "|" + (string)team);
    updateDisplays();
}

unregisterPlayer(key avatarKey) {
    integer slot = findPlayerSlot(avatarKey);
    if (slot == -1) return;
    setPlayer(slot, NULL_KEY, "", 0, FALSE, FALSE, 0, "", "");
    updateDisplays();
}

// ── Leitura do notecard de configuração ─────────────────────────────────────────
readConfig() {
    gConfigNCKey = llGetNotecardLine(gConfigName, 0);
    gConfigLine = 0;
}

processConfigLine(string line) {
    line = llStringTrim(line, STRING_TRIM);
    if (line == "" || llGetSubString(line, 0, 0) == "#") return;  // Comentário

    list parts = llParseString2List(line, ["="], []);
    if (llGetListLength(parts) < 2) return;

    string key = llStringTrim(llList2String(parts, 0), STRING_TRIM);
    string val = llStringTrim(llList2String(parts, 1), STRING_TRIM);

    if (key == "NUM_DECKS")      NUM_DECKS = (integer)val;
    else if (key == "NUM_ROUNDS") NUM_ROUNDS = (integer)val;
    else if (key == "CLEAN_BOOK") CLEAN_BOOK = (integer)val;
    else if (key == "DIRTY_BOOK") DIRTY_BOOK = (integer)val;
    else if (key == "RED3_BONUS") RED3_BONUS = (integer)val;
    else if (key == "GO_OUT_BONUS") GO_OUT_BONUS = (integer)val;
    else if (key == "MIN_MELD")   MIN_MELD_LADDER = llParseString2List(val, [","], []);
    else if (key == "ATLAS1_UUID") gAtlas1UUID = val;
    else if (key == "ATLAS2_UUID") gAtlas2UUID = val;
    else if (key == "CARDBACK_UUID") gCardBackUUID = val;
}

// ── Inicialização ──────────────────────────────────────────────────────────────
initGame() {
    gBaseChan = calcBaseChan();
    gGameActive = FALSE;
    gRoundActive = FALSE;
    gRoundNum = 0;
    gCurrentPlayer = 0;
    gTurnPhase = "";
    gStock = [];
    gDiscard = [];
    gNextUid = 0;

    // Inicializar jogadores (vazios)
    gPlayers = [];
    integer i;
    for (i = 0; i < NUM_PLAYERS; i++) {
        gPlayers += [NULL_KEY, "", 0, FALSE, FALSE, 0, "", ""];
    }

    // Inicializar times
    gTeams = [FALSE, 0, "", FALSE, 0, ""];

    // Ler config
    if (llGetInventoryType(gConfigName) == INVENTORY_NOTECARD) {
        readConfig();
    } else {
        llOwnerSay("Notecard '" + gConfigName + "' não encontrado — usando padrões");
    }

    // Setup listen
    gListenHandle = llListen(gBaseChan, "", NULL_KEY, "");

    llOwnerSay("Hand & Foot Canasta Engine inicializado (canal " + (string)gBaseChan + ")");
    llSetTimerEvent(0);
}

// ── STATES ─────────────────────────────────────────────────────────────────────
default {
    state_entry() {
        initGame();
    }

    on_rez(integer param) {
        initGame();
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }

    // ── Notecard reading ───────────────────────────────────────────────────
    dataserver(key queryId, string data) {
        if (queryId == gConfigNCKey) {
            if (data != EOF) {
                processConfigLine(data);
                gConfigLine++;
                gConfigNCKey = llGetNotecardLine(gConfigName, gConfigLine);
            } else {
                llOwnerSay("Config carregado: " + (string)NUM_DECKS + " baralhos, " +
                           (string)NUM_ROUNDS + " rodadas, minMeld=" + llList2CSV(MIN_MELD_LADDER));
            }
        }
    }

    // ── Listen (comandos do HUD e chat) ────────────────────────────────────
    listen(integer channel, string name, key id, string msg) {
        // Comandos de chat do owner
        if (channel == 0 && id == llGetOwner()) {
            if (msg == "start" || msg == "iniciar") {
                // Verificar jogadores suficientes
                integer count = 0;
                integer i;
                for (i = 0; i < NUM_PLAYERS; i++) {
                    if (playerKey(i) != NULL_KEY) count++;
                }
                if (count < 2) {
                    llOwnerSay("Precisa de pelo menos 2 jogadores!");
                    return;
                }
                gGameActive = TRUE;
                gRoundNum = 0;
                integer t;
                for (t = 0; t < 2; t++) {
                    setTeamScore(t, 0);
                    setTeamMelds(t, "");
                    setTeamIsDown(t, FALSE);
                }
                dealRound();
                return;
            }
            if (msg == "nextround" || msg == "proxrodada") {
                if (!gGameActive) {
                    llOwnerSay("Nenhum jogo ativo. Diga 'start' para começar.");
                    return;
                }
                gRoundNum++;
                if (gRoundNum >= NUM_ROUNDS) {
                    llOwnerSay("Todas as rodadas já foram jogadas!");
                    return;
                }
                dealRound();
                return;
            }
            if (msg == "reset" || msg == "reiniciar") {
                initGame();
                llOwnerSay("Jogo reiniciado.");
                return;
            }
            if (msg == "status") {
                llOwnerSay("Rodada: " + (string)(gRoundNum+1) + "/" + (string)NUM_ROUNDS +
                           " | Jogador: " + (string)(gCurrentPlayer+1) +
                           " | Fase: " + gTurnPhase +
                           " | Stock: " + (string)llGetListLength(gStock) +
                           " | Descarte: " + (string)llGetListLength(gDiscard) +
                           " | T1: " + (string)teamScore(0) + " | T2: " + (string)teamScore(1));
                return;
            }
            if (msg == "help" || msg == "ajuda") {
                llOwnerSay("Comandos: start | nextround | reset | status | help");
                return;
            }
        }

        // Comandos do HUD (no canal base)
        if (channel == gBaseChan) {
            list parts = llParseString2List(msg, ["|"], []);
            string cmd = llList2String(parts, 0);
            string data1 = llList2String(parts, 1);

            // Identificar jogador pelo id
            integer pIdx = -1;
            integer i;
            for (i = 0; i < NUM_PLAYERS; i++) {
                if (playerKey(i) == id) { pIdx = i; jump found_player; }
            }
            @found_player;

            if (pIdx == -1) return;  // Jogador não registrado

            if (cmd == "DRAW") {
                processDraw(pIdx);
            } else if (cmd == "TAKE_DISCARD") {
                processTakeDiscard(pIdx);
            } else if (cmd == "TAKE_PILE") {
                processTakePile(pIdx);
            } else if (cmd == "MELD") {
                // data1 = "uid1,uid2,uid3,..."
                list uids = llParseString2List(data1, [","], []);
                list intUids;
                for (i = 0; i < llGetListLength(uids); i++) {
                    intUids += [(integer)llList2String(uids, i)];
                }
                processMeld(pIdx, intUids);
            } else if (cmd == "DISCARD") {
                processDiscard(pIdx, (integer)data1);
            } else if (cmd == "REQUEST_HAND") {
                sendHandToHUD(pIdx);
            } else if (cmd == "REQUEST_STATE") {
                sendGameState();
            }
        }
    }

    // ── Link messages (de prims filhos) ────────────────────────────────────
    link_message(integer sender, integer num, string str, key id) {
        // 200 = jogador sentou no assento
        if (num == 200) {
            registerPlayer(id, str);
        }
        // 201 = jogador levantou
        else if (num == 201) {
            unregisterPlayer(id);
        }
    }

    // ── Touch (owner menu) ─────────────────────────────────────────────────
    touch_start(integer n) {
        if (llDetectedKey(0) == llGetOwner()) {
            llDialog(llDetectedKey(0),
                "Hand & Foot Canasta\nRodada: " + (string)(gRoundNum+1) + "/" + (string)NUM_ROUNDS +
                "\nT1: " + (string)teamScore(0) + " | T2: " + (string)teamScore(1),
                ["Iniciar", "Próx Rodada", "Reiniciar", "Status"],
                gBaseChan);
        }
    }
}
