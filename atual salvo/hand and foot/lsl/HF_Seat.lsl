// ═══════════════════════════════════════════════════════════════════════════════
// HF_Seat.lsl — Script de Assento para Hand & Foot Canasta
// Colocar em cada prim de assento (child da mesa).
//
// Funcionalidades:
//   - Permite que avatares sentem (llSitTarget)
//   - Detecta quando um avatar senta/levanta
//   - Notifica o motor via link_message
//   - Mostra nome do jogador e status via floating text
//   - Entrega o HUD ao jogador (se no inventário)
//
// Versão: 1.0.0
// ═══════════════════════════════════════════════════════════════════════════════

// ── Constantes ──────────────────────────────────────────────────────────────────
vector  SIT_OFFSET = <0.0, 0.0, 0.5>;    // Offset do assento
vector  SIT_ROT    = <0.0, 0.0, 0.0>;    // Rotação ao sentar
string  HUD_OBJECT = "HF HUD";           // Nome do HUD no inventário

// ── Variáveis ──────────────────────────────────────────────────────────────────
key     gSeatedAvatar = NULL_KEY;
string  gSeatedName = "";
integer gSeatIndex = 0;    // Configurado via description do prim (0-3)

// ── Funções auxiliares ──────────────────────────────────────────────────────────
updateFloatText(string text) {
    if (text == "") {
        llSetText("", <1,1,1>, 0);
    } else {
        llSetText(text, <1, 1, 0.8>, 1.0);
    }
}

deliverHUD(key avatar) {
    // Verificar se o HUD está no inventário do prim raiz
    integer idx = llGetInventoryType(HUD_OBJECT);
    if (idx == INVENTORY_OBJECT) {
        llGiveInventory(avatar, HUD_OBJECT);
        llOwnerSay("HUD entregue a " + llKey2Name(avatar));
    }
}

// ── STATES ─────────────────────────────────────────────────────────────────────
default {
    state_entry() {
        // Configurar sit target
        llSitTarget(SIT_OFFSET, llEuler2Rot(SIT_ROT * DEG_TO_RAD));

        // Ler seat index do description
        string desc = llGetObjectDesc();
        if (desc != "" && (integer)desc >= 0 && (integer)desc < 4) {
            gSeatIndex = (integer)desc;
        }

        updateFloatText("Assento " + (string)(gSeatIndex + 1) + "\n(sente-se aqui)");
    }

    changed(integer change) {
        if (change & CHANGED_LINK) {
            key seated = llAvatarOnSitTarget();

            if (seated != NULL_KEY && gSeatedAvatar == NULL_KEY) {
                // Alguém sentou
                gSeatedAvatar = seated;
                gSeatedName = llKey2Name(seated);

                updateFloatText(gSeatedName + "\nAssento " + (string)(gSeatIndex + 1));

                // Notificar o motor (link message 200)
                llMessageLinked(LINK_ROOT, 200, gSeatedName, seated);

                // Entregar HUD
                deliverHUD(seated);

            } else if (seated == NULL_KEY && gSeatedAvatar != NULL_KEY) {
                // Alguém levantou
                // Notificar o motor (link message 201)
                llMessageLinked(LINK_ROOT, 201, "", gSeatedAvatar);

                gSeatedAvatar = NULL_KEY;
                gSeatedName = "";

                updateFloatText("Assento " + (string)(gSeatIndex + 1) + "\n(sente-se aqui)");
            }
        }
    }

    // ── Link messages (do motor) ────────────────────────────────────────────
    link_message(integer sender, integer num, string str, key id) {
        // 102-105 = atualizar floating text do assento
        if (num == 102 + gSeatIndex) {
            if (gSeatedAvatar != NULL_KEY) {
                updateFloatText(str + "\nAssento " + (string)(gSeatIndex + 1));
            }
        }
    }

    touch_start(integer n) {
        key toucher = llDetectedKey(0);
        if (toucher == gSeatedAvatar) {
            // Jogador já sentado — pode interagir
            llRegionSayTo(toucher, 0, "Você está no assento " + (string)(gSeatIndex + 1) + ". Use o HUD ou toque na mesa para jogar.");
        } else if (gSeatedAvatar == NULL_KEY) {
            llRegionSayTo(toucher, 0, "Sente-se aqui para jogar!");
        }
    }
}
