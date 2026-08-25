/*
 * ============================================================
 * SL TV Sync - Script da Tela (TV) para Second Life
 * ============================================================
 * Este script configura automaticamente o Shared Media (Media on a Prim)
 * da face frontal do prim para exibir o player sincronizado.
 *
 * INSTRUCOES:
 * 1. Crie um prim e deixe a face 0 como a tela da TV.
 * 2. V em Edit > Content > New Script.
 * 3. Apague o conteudo padrao e cole este codigo.
 * 4. Altere SERVER_URL para a URL do seu servidor na nuvem.
 * 5. Salve (Ctrl+S). A tela deve ficar com a URL do player.
 * 6. Se a tela estiver preta, clique com botao direito na TV > Refresh Media.
 *
 * DICAS:
 * - Ajuste o tamanho do prim para aspecto 16:9 (ex: 2m x 1.125m).
 * - Desative "Glow" excessive para nao ofuscar a tela.
 * - A URL pode conter ?channel= para separar salas.
 */

string SERVER_URL = "https://SEU-SERVIDOR-AQUI.onrender.com/"; // <-- ALTERE AQUI
string CHANNEL_ID = "main-living-room";                           // <-- Canal da TV
integer MEDIA_FACE = 0;                                           // Face 0 = frente
integer SCREEN_WIDTH = 1024;                                      // Resolucao horizontal
integer SCREEN_HEIGHT = 576;                                      // Resolucao vertical (16:9)

setup_media()
{
    // Monta a URL do player com o canal.
    string url = SERVER_URL + "?channel=" + llEscapeURL(CHANNEL_ID);

    // Limpa media anterior para evitar sobreposicao.
    llClearLinkMedia(LINK_THIS, MEDIA_FACE);

    // Configura o Shared Media na face.
    llSetLinkMedia(LINK_THIS, MEDIA_FACE, [
        PRIM_MEDIA_AUTO_PLAY, TRUE,
        PRIM_MEDIA_CURRENT_URL, url,
        PRIM_MEDIA_HOME_URL, url,
        PRIM_MEDIA_INTERACTIVE, FALSE,       // Desativa interacao do usuario
        PRIM_MEDIA_WIDTH_PIXELS, SCREEN_WIDTH,
        PRIM_MEDIA_HEIGHT_PIXELS, SCREEN_HEIGHT,
        PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_NONE,
        PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_NONE
    ]);

    llOwnerSay("SL TV Sync iniciado no canal: " + CHANNEL_ID);
    llOwnerSay("URL: " + url);
}

say_dashboard()
{
    llSay(0, "Abra o dashboard para controlar esta TV: " + SERVER_URL + "dashboard.html");
}

default
{
    state_entry()
    {
        setup_media();
    }

    on_rez(integer start_param)
    {
        setup_media();
    }

    changed(integer change)
    {
        // Reconfigura se o objeto mudar de regiao ou for modificado.
        if (change & (CHANGED_REGION_START | CHANGED_OWNER | CHANGED_INVENTORY))
        {
            setup_media();
        }
    }

    touch_start(integer total_number)
    {
        say_dashboard();
    }
}
