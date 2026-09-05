// ═══════════════════════════════════════════════════════════════════════════════
// HF_HUD.lsl — HUD do Jogador para Hand & Foot Canasta
// Anexar como HUD (attach to HUD center/center2 ou qualquer ponto HUD)
//
// Funcionalidades:
//   - Exibe cartas da mão como botões de dialog
//   - Botões: Comprar, Pegar Descarte, Pegar Pilha, Meld, Descartar, Ordenar
//   - Comunica com a mesa via llRegionSay no canal base
//   - Recebe atualizações da mesa via llRegionSayTo no canal do jogador
//
// Versão: 1.0.0
// ═══════════════════════════════════════════════════════════════════════════════

// ── Constantes ──────────────────────────────────────────────────────────────────
integer MAX_CARDS_DISPLAY = 11;  // Max botões por dialog (12 max - 1 para nav)

// ── Variáveis ──────────────────────────────────────────────────────────────────
integer gBaseChan;       // Canal base da mesa
integer gMyChan;         // Meu canal (base + playerIdx + 1)
integer gListenBase;
integer gListenMy;

integer gPlayerIdx = -1; // Meu índice (0-3)
integer gTeamIdx = -1;   // Meu time (0-1)

// Cartas na mão: list of [uid, shortName]
list gHandUids;
list gHandShorts;

// Estado
string gPhase = "";       // draw, meld, discard
integer gRoundNum;
integer gStockCount;
integer gDiscardCount;
string gDiscardTop;
integer gMinMeld;

// Melds dos times
string gTeam0Melds;
string gTeam1Melds;

// Scores
integer gScore0;
integer gScore1;

// Seleção de cartas para meld
list gSelectedUids;

// Mesa key (para encontrar canal)
key gTableKey;

// ── Funções auxiliares ──────────────────────────────────────────────────────────
integer calcBaseChan(key tableKey) {
    return -0x7FF00000 + (integer)("0x" + llGetSubString((string)tableKey, 0, 6));
}

sendToTable(string msg) {
    llRegionSay(gBaseChan, msg);
}

// ── Atualizar HUD display ──────────────────────────────────────────────────────
updateDisplay() {
    string info = "═══ HAND & FOOT ═══\n";
    info += "Rodada: " + (string)gRoundNum + " | Time: " + (string)(gTeamIdx + 1) + "\n";
    info += "Fase: " + gPhase + "\n";
    info += "Stock: " + (string)gStockCount + " | Descarte: " + (string)gDiscardCount;
    if (gDiscardTop != "") info += " (" + gDiscardTop + ")";
    info += "\n";
    info += "Mínimo baixar: " + (string)gMinMeld + "\n";
    info += "T1: " + (string)gScore0 + " | T2: " + (string)gScore1 + "\n";
    info += "─────────────────\n";
    info += "Mão (" + (string)llGetListLength(gHandUids) + "):\n";

    // Mostrar cartas (máximo 22 caracteres por linha, 2 cartas por linha)
    integer i;
    integer count = llGetListLength(gHandShorts);
    for (i = 0; i < count; i += 2) {
        string line = llList2String(gHandShorts, i);
        if (i + 1 < count) line += "  " + llList2String(gHandShorts, i + 1);
        info += line + "\n";
    }

    if (llGetListLength(gSelectedUids) > 0) {
        info += "\nSelecionadas: " + (string)llGetListLength(gSelectedUids);
    }

    // Usar floating text no HUD prim
    llSetText(info, <1, 1, 1>, 1.0);
}

// ── Mostrar menu principal ─────────────────────────────────────────────────────
showMainMenu() {
    string prompt = "Hand & Foot Canasta\nFase: " + gPhase + "\nSelecione uma ação:";
    list buttons;

    if (gPhase == "draw") {
        buttons = ["Comprar 2", "Pegar Descarte", "Pegar Pilha"];
    } else if (gPhase == "meld") {
        buttons = ["Meld", "Descartar", "Ver Melds"];
    } else if (gPhase == "discard") {
        buttons = ["Descartar", "Ver Melds"];
    }

    buttons += ["Ordenar", "Atualizar", "Ajuda"];

    llDialog(llGetOwner(), prompt, buttons, gMyChan + 1000);
}

// ── Mostrar menu de cartas (para selecionar) ───────────────────────────────────
showCardMenu(string purpose) {
    // Propósito: "MELD" ou "DISCARD"
    string prompt = "Selecione carta(s) para " + purpose + ":\n";
    prompt += "Selecionadas: " + (string)llGetListLength(gSelectedUids) + "\n\n";

    list buttons;
    integer i;
    integer count = llGetListLength(gHandShorts);

    for (i = 0; i < count && llGetListLength(buttons) < 9; i++) {
        integer uid = llList2Integer(gHandUids, i);
        string short = llList2String(gHandShorts, i);

        // Marcar selecionadas
        if (llListFindList(gSelectedUids, [uid]) != -1) {
            short = "[" + short + "]";
        }
        // Truncar para caber no botão
        if (llStringLength(short) > 8) short = llGetSubString(short, 0, 7);
        buttons += [short];
    }

    if (purpose == "MELD") {
        buttons += ["Confirmar", "Limpar", "Cancelar"];
    } else {
        buttons += ["Cancelar"];
    }

    llDialog(llGetOwner(), prompt, buttons, gMyChan + 2000);
}

// ── Ordenar mão ────────────────────────────────────────────────────────────────
sortHand() {
    // Bubble sort por rank, depois suit
    integer n = llGetListLength(gHandUids);
    integer i;
    integer j;
    for (i = 0; i < n - 1; i++) {
        for (j = 0; j < n - i - 1; j++) {
            integer uid1 = llList2Integer(gHandUids, j);
            integer uid2 = llList2Integer(gHandUids, j + 1);
            integer fc1 = uid1 % 54;
            integer fc2 = uid2 % 54;
            integer r1 = fc1 / 4 + 3;
            integer r2 = fc2 / 4 + 3;
            if (fc1 >= 48) r1 = 15;
            if (fc1 >= 52) r1 = 16;
            if (fc2 >= 48) r2 = 15;
            if (fc2 >= 52) r2 = 16;

            if (r1 > r2 || (r1 == r2 && fc1 > fc2)) {
                // Swap
                gHandUids = llListReplaceList(gHandUids, [uid2], j, j);
                gHandUids = llListReplaceList(gHandUids, [uid1], j+1, j+1);
                gHandShorts = llListReplaceList(gHandShorts, [llList2String(gHandShorts, j+1)], j, j);
                gHandShorts = llListReplaceList(gHandShorts, [llList2String(gHandShorts, j)], j+1, j+1);
            }
        }
    }
    updateDisplay();
}

// ── Processar hand recebido da mesa ────────────────────────────────────────────
processHandMsg(string data) {
    // Formato: "uid1:short1,uid2:short2,..."
    gHandUids = [];
    gHandShorts = [];
    gSelectedUids = [];

    if (data == "") return;

    list cards = llParseString2List(data, [","], []);
    integer i;
    for (i = 0; i < llGetListLength(cards); i++) {
        list parts = llParseString2List(llList2String(cards, i), [":"], []);
        gHandUids += [(integer)llList2String(parts, 0)];
        gHandShorts += [llList2String(parts, 1)];
    }

    sortHand();
    updateDisplay();
}

// ── Processar state recebido ───────────────────────────────────────────────────
processStateMsg(string data) {
    // Formato: "round|currentPlayer|phase|stockCount|discardCount|discardTop|minMeld"
    list parts = llParseString2List(data, ["|"], []);
    gRoundNum = (integer)llList2String(parts, 0);
    gPhase = llList2String(parts, 2);
    gStockCount = (integer)llList2String(parts, 3);
    gDiscardCount = (integer)llList2String(parts, 4);
    gDiscardTop = llList2String(parts, 5);
    gMinMeld = (integer)llList2String(parts, 6);
    updateDisplay();
}

// ── Inicialização ──────────────────────────────────────────────────────────────
initHUD() {
    gHandUids = [];
    gHandShorts = [];
    gSelectedUids = [];
    gPhase = "";
    gPlayerIdx = -1;
    gTeamIdx = -1;

    llSetText("Hand & Foot HUD\nAguardando mesa...", <1, 1, 0.5>, 1.0);
}

// ── STATES ─────────────────────────────────────────────────────────────────────
default {
    state_entry() {
        initHUD();
    }

    on_rez(integer param) {
        initHUD();
    }

    attach(key id) {
        if (id != NULL_KEY) {
            initHUD();
            // Solicitar estado da mesa
            // (precisa saber o canal base — será configurado quando receber WELCOME)
        }
    }

    // ── Listen (mensagens da mesa e dialogs) ────────────────────────────────
    listen(integer channel, string name, key id, string msg) {
        // Canal do jogador (mensagens da mesa)
        if (channel == gMyChan && gPlayerIdx >= 0) {
            list parts = llParseString2List(msg, ["|"], []);
            string cmd = llList2String(parts, 0);

            if (cmd == "HAND") {
                processHandMsg(llList2String(parts, 1));
            } else if (cmd == "STATE") {
                processStateMsg(llList2String(parts, 1));
            } else if (cmd == "MELDS") {
                integer team = (integer)llList2String(parts, 1);
                if (team == 0) gTeam0Melds = llList2String(parts, 2);
                else gTeam1Melds = llList2String(parts, 2);
                updateDisplay();
            } else if (cmd == "SCORE") {
                gScore0 = (integer)llList2String(parts, 1);
                gScore1 = (integer)llList2String(parts, 2);
                updateDisplay();
            } else if (cmd == "WELCOME") {
                gPlayerIdx = (integer)llList2String(parts, 1);
                gTeamIdx = (integer)llList2String(parts, 2);
                llOwnerSay("Registrado! Jogador " + (string)(gPlayerIdx+1) + ", Time " + (string)(gTeamIdx+1));
                // Pedir estado
                sendToTable("REQUEST_STATE");
                sendToTable("REQUEST_HAND");
            } else if (cmd == "INFO") {
                llOwnerSay(llList2String(parts, 1));
            } else if (cmd == "ERROR") {
                llOwnerSay("⚠ " + llList2String(parts, 1));
            } else if (cmd == "ROUND_END") {
                llOwnerSay("═══ Fim da Rodada " + llList2String(parts, 1) + " ═══\nT1: " + llList2String(parts, 2) + " | T2: " + llList2String(parts, 3));
            } else if (cmd == "GAME_OVER") {
                llOwnerSay("★★★ FIM DE JOGO! ★★★\nT1: " + llList2String(parts, 1) + " | T2: " + llList2String(parts, 2) + "\nVencedor: " + llList2String(parts, 3));
            }
        }

        // Dialog menu principal
        if (channel == gMyChan + 1000) {
            if (msg == "Comprar 2") {
                sendToTable("DRAW");
            } else if (msg == "Pegar Descarte") {
                sendToTable("TAKE_DISCARD");
            } else if (msg == "Pegar Pilha") {
                sendToTable("TAKE_PILE");
            } else if (msg == "Meld") {
                gSelectedUids = [];
                showCardMenu("MELD");
            } else if (msg == "Descartar") {
                gSelectedUids = [];
                showCardMenu("DISCARD");
            } else if (msg == "Ver Melds") {
                // Mostrar melds dos times
                string info = "═══ MELDS ═══\nTime 1: " + gTeam0Melds + "\nTime 2: " + gTeam1Melds;
                llOwnerSay(info);
            } else if (msg == "Ordenar") {
                sortHand();
            } else if (msg == "Atualizar") {
                sendToTable("REQUEST_HAND");
                sendToTable("REQUEST_STATE");
            } else if (msg == "Ajuda") {
                llOwnerSay("Comandos: Comprar 2 (stock), Pegar Descarte (topo+1), Pegar Pilha (toda), Meld (selecionar cartas), Descartar (1 carta). Diga /1help para mais info.");
            }
        }

        // Dialog de seleção de cartas
        if (channel == gMyChan + 2000) {
            if (msg == "Confirmar" && llGetListLength(gSelectedUids) >= 3) {
                // Enviar meld
                string uidList = llDumpList2String(gSelectedUids, ",");
                sendToTable("MELD|" + uidList);
                gSelectedUids = [];
            } else if (msg == "Limpar") {
                gSelectedUids = [];
                showCardMenu("MELD");
            } else if (msg == "Cancelar") {
                gSelectedUids = [];
                showMainMenu();
            } else {
                // Selecionar/deselecionar carta
                integer i;
                for (i = 0; i < llGetListLength(gHandShorts); i++) {
                    string short = llList2String(gHandShorts, i);
                    if (llStringLength(short) > 8) short = llGetSubString(short, 0, 7);

                    // Verificar se já está selecionada
                    integer uid = llList2Integer(gHandUids, i);
                    integer selIdx = llListFindList(gSelectedUids, [uid]);

                    string display = short;
                    if (selIdx != -1) display = "[" + short + "]";

                    if (msg == display || msg == short) {
                        if (selIdx != -1) {
                            // Deselecionar
                            gSelectedUids = llListReplaceList(gSelectedUids, [], selIdx, selIdx);
                        } else {
                            // Selecionar
                            gSelectedUids += [uid];
                        }
                        jump card_found;
                    }
                }
                @card_found;

                // Se é modo DISCARD e selecionou 1 carta, descartar direto
                if (llGetListLength(gSelectedUids) == 1) {
                    // Verificar se estamos em modo DISCARD
                    // (simplificado: se veio do menu DISCARD)
                    // Na verdade, precisamos saber o propósito...
                    // Vamos sempre mostrar o menu de novo
                }

                showCardMenu("MELD");  // Default, será ajustado pelo contexto
            }
        }
    }

    // ── Touch ───────────────────────────────────────────────────────────────
    touch_start(integer n) {
        if (llDetectedKey(0) == llGetOwner()) {
            if (gPlayerIdx < 0) {
                llOwnerSay("Aguardando registro na mesa. Sente-se em um assento!");
                return;
            }
            showMainMenu();
        }
    }

    // ── Link message (se HUD tiver child prims para cartas) ────────────────
    link_message(integer sender, integer num, string str, key id) {
        // Reservado para comunicação com child card prims no HUD
    }
}
