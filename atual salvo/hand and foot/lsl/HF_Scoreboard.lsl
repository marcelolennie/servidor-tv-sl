// ═══════════════════════════════════════════════════════════════════════════════
// HF_Scoreboard.lsl — Placar para Hand & Foot Canasta
// Colocar no prim do placar (child da mesa).
//
// Mostra pontuação dos dois times e informações da rodada.
// Atualizado via link messages do motor.
//
// Versão: 1.0.0
// ═══════════════════════════════════════════════════════════════════════════════

// ── Variáveis ──────────────────────────────────────────────────────────────────
integer gScore0 = 0;
integer gScore1 = 0;
integer gStockCount = 0;
integer gDiscardCount = 0;
string  gDiscardTop = "";
integer gRoundNum = 0;
integer gMinMeld = 50;

// ── Atualizar display ──────────────────────────────────────────────────────────
updateDisplay() {
    string text = "╔══════════════════════╗\n";
    text += "║  HAND & FOOT CANASTA ║\n";
    text += "╠══════════════════════╣\n";
    text += "║ Rodada: " + fmtNum(gRoundNum, 2) + "           ║\n";
    text += "║ Mínimo: " + fmtNum(gMinMeld, 3) + "          ║\n";
    text += "╠══════════════════════╣\n";
    text += "║ Time 1: " + fmtNum(gScore0, 5) + "       ║\n";
    text += "║ Time 2: " + fmtNum(gScore1, 5) + "       ║\n";
    text += "╠══════════════════════╣\n";
    text += "║ Stock: " + fmtNum(gStockCount, 3) + "  Desc: " + fmtNum(gDiscardCount, 3) + "  ║\n";
    if (gDiscardTop != "") {
        text += "║ Topo: " + gDiscardTop + "             ║\n";
    }
    text += "╚══════════════════════╝";

    llSetText(text, <1, 1, 0.8>, 1.0);
}

string fmtNum(integer n, integer width) {
    string s = (string)n;
    while (llStringLength(s) < width) s = " " + s;
    return s;
}

// ── STATES ─────────────────────────────────────────────────────────────────────
default {
    state_entry() {
        updateDisplay();
    }

    // ── Link messages (do motor) ────────────────────────────────────────────
    link_message(integer sender, integer num, string str, key id) {
        // 100 = atualizar scores: "score0|score1"
        if (num == 100) {
            list parts = llParseString2List(str, ["|"], []);
            gScore0 = (integer)llList2String(parts, 0);
            gScore1 = (integer)llList2String(parts, 1);
            updateDisplay();
        }
        // 101 = atualizar piles: "stockCount|discardCount|discardTopUid"
        else if (num == 101) {
            list parts = llParseString2List(str, ["|"], []);
            gStockCount = (integer)llList2String(parts, 0);
            gDiscardCount = (integer)llList2String(parts, 1);
            // discardTopUid pode ser traduzido para nome curto
            string topUid = llList2String(parts, 2);
            if (topUid != "" && topUid != "0") {
                // Decodificar face
                integer uid = (integer)topUid;
                integer fc = uid % 54;
                integer r;
                if (fc < 48) r = (fc / 4) + 3;
                else if (fc < 52) r = 15;
                else r = 16;
                integer s;
                if (fc < 52) s = fc % 4;
                else s = 0;

                string rs;
                if (r <= 10) rs = (string)r;
                else if (r == 11) rs = "J";
                else if (r == 12) rs = "Q";
                else if (r == 13) rs = "K";
                else if (r == 14) rs = "A";
                else if (r == 15) rs = "2";
                else rs = "Jk";

                string ss;
                if (r == 16) { ss = "V"; if (s == 0) ss = "P"; }
                else {
                    if (s == 0) ss = "♣";
                    else if (s == 1) ss = "♦";
                    else if (s == 2) ss = "♥";
                    else ss = "♠";
                }
                gDiscardTop = rs + ss;
            } else {
                gDiscardTop = "";
            }
            updateDisplay();
        }
    }

    touch_start(integer n) {
        // Ao tocar, mostrar detalhes no chat do toucher
        llRegionSayTo(llDetectedKey(0), 0,
            "Hand & Foot Canasta\n" +
            "Rodada: " + (string)gRoundNum + "\n" +
            "Time 1: " + (string)gScore0 + " | Time 2: " + (string)gScore1 + "\n" +
            "Stock: " + (string)gStockCount + " | Descarte: " + (string)gDiscardCount);
    }
}
