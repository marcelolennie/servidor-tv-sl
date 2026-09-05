// ═══════════════════════════════════════════════════════════════════════════════
// HF_Card.lsl — Script para cada carta rezzada na mesa
// Colocar no objeto "HF Card" que fica no inventário do prim raiz.
//
// Quando rezzado, recebe via on_rez ou llListen:
//   - faceCode (para determinar textura/atlas offsets)
//   - posição e rotação alvo
//
// A carta usa o atlas de texturas com offsets para mostrar a face correta.
// Face 0 (topo) = face da carta; Face 1 (baixo) = verso.
//
// Versão: 1.0.0
// ═══════════════════════════════════════════════════════════════════════════════

// ── Constantes ──────────────────────────────────────────────────────────────────
// Atlas: 1024x1024, 8 cols x 4 rows, cada célula 128x256
float H_REPEAT = 0.125;   // 1/8
float V_REPEAT = 0.25;    // 1/4

// UUIDs das texturas (lidos do notecard ou passados via parâmetro)
string gAtlas1UUID;
string gAtlas2UUID;
string gCardBackUUID;

// ── Variáveis ──────────────────────────────────────────────────────────────────
integer gFaceCode = -1;    // 0-53
integer gUid = -1;         // UID único da carta
integer gListenHandle;

// ── Calcular offsets da textura ─────────────────────────────────────────────────
setCardTexture(integer faceCode) {
    integer atlasNum;
    integer col;
    integer row;

    if (faceCode < 32) {
        atlasNum = 1;
        col = faceCode % 8;
        row = faceCode / 8;
    } else {
        atlasNum = 2;
        col = (faceCode - 32) % 8;
        row = (faceCode - 32) / 8;
    }

    float hOffset = col * H_REPEAT;
    float vOffset = 1.0 - (row + 1) * V_REPEAT;

    string atlasUUID;
    if (atlasNum == 1) atlasUUID = gAtlas1UUID;
    else atlasUUID = gAtlas2UUID;

    // Face 0 = topo da carta (face visível quando virada para cima)
    llSetPrimitiveParams([
        PRIM_TEXTURE, 0,          // Face 0 (topo)
            atlasUUID,            // Textura atlas
            <H_REPEAT, V_REPEAT, 0>,  // Repeat
            <hOffset, vOffset, 0>,     // Offset
            0.0,                  // Rotation
        PRIM_TEXTURE, 1,          // Face 1 (baixo/verso)
            gCardBackUUID,        // Textura de verso
            <1.0, 1.0, 0>,        // Repeat (back texture is 128x256, full)
            <0.0, 0.0, 0>,        // Offset
            0.0                   // Rotation
    ]);
}

// Virar carta para baixo (mostrar verso)
showBack() {
    llSetPrimitiveParams([
        PRIM_TEXTURE, 0,
            gCardBackUUID,
            <1.0, 1.0, 0>,
            <0.0, 0.0, 0>,
            0.0
    ]);
}

// Virar carta para cima (mostrar face)
showFace() {
    if (gFaceCode >= 0) {
        setCardTexture(gFaceCode);
    }
}

// ── STATES ─────────────────────────────────────────────────────────────────────
default {
    state_entry() {
        // Carta criada mas sem face — mostrar verso
        if (gCardBackUUID != "") {
            showBack();
        }
        // Listen para comandos
        gListenHandle = llListen(-0x7FF00000 + (integer)("0x" + llGetSubString((string)llGetKey(), 0, 6)), "", NULL_KEY, "");
    }

    on_rez(integer param) {
        // param = faceCode (0-53) se positivo, ou código especial
        if (param > 0 && param < 54) {
            gFaceCode = param;
            showFace();
        } else if (param == 0) {
            showBack();
        }

        // Timer para auto-deletar se temporário
        llSetTimerEvent(0);
    }

    listen(integer channel, string name, key id, string msg) {
        list parts = llParseString2List(msg, ["|"], []);
        string cmd = llList2String(parts, 0);

        if (cmd == "SET_FACE") {
            gFaceCode = (integer)llList2String(parts, 1);
            gUid = (integer)llList2String(parts, 2);
            showFace();
        } else if (cmd == "SET_TEXTURES") {
            gAtlas1UUID = llList2String(parts, 1);
            gAtlas2UUID = llList2String(parts, 2);
            gCardBackUUID = llList2String(parts, 3);
            if (gFaceCode >= 0) showFace();
            else showBack();
        } else if (cmd == "SHOW_BACK") {
            showBack();
        } else if (cmd == "SHOW_FACE") {
            showFace();
        } else if (cmd == "DIE") {
            llDie();
        }
    }

    touch_start(integer n) {
        // Click na carta — notificar a mesa
        // Enviar click event via llRegionSay
        integer baseChan = -0x7FF00000 + (integer)("0x" + llGetSubString((string)llGetOwner(), 0, 6));
        llRegionSay(baseChan, "CARD_CLICK|" + (string)gUid + "|" + (string)gFaceCode);
    }

    timer() {
        // Auto-deletar após timeout (se temporário)
        llDie();
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}
