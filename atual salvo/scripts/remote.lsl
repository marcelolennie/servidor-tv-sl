/*
 * SL TV Sync - Remote Control (LSL)
 * Objeto opcional para controle remoto dentro do Second Life.
 * Envia comandos para o servidor via HTTP (requer endpoint /api/control + secret).
 * Use com cuidado: secret hardcoded em LSL pode ser lido por outros residentes.
 */

string SERVER_URL = "https://SEU-SERVIDOR-AQUI.onrender.com"; // <-- ALTERE
string ADMIN_SECRET = "SEU-SECRET-AQUI"; // <-- ALTERE
string CHANNEL_ID = "main-living-room";

sendCommand(string action, string url, string title)
{
    string body = "{"
        + "\"secret\":\"" + ADMIN_SECRET + "\","
        + "\"action\":\"" + action + "\","
        + "\"channelId\":\"" + CHANNEL_ID + "\","
        + "\"title\":\"" + title + "\","
        + "\"url\":\"" + url + "\","
        + "\"sourceType\":\"youtube\""
        + "}";

    llHTTPRequest(
        SERVER_URL + "/api/control",
        [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"],
        body
    );

    llOwnerSay("Comando enviado: " + action);
}

default
{
    state_entry()
    {
        llListen(0, "", llGetOwner(), "");
    }

    listen(integer channel, string name, key id, string message)
    {
        if (id != llGetOwner()) return;

        list parts = llParseString2List(message, [" "], []);
        string cmd = llToLower(llList2String(parts, 0));

        if (cmd == "tvplay")
        {
            sendCommand("play", "", "");
        }
        else if (cmd == "tvpause")
        {
            sendCommand("pause", "", "");
        }
        else if (cmd == "tvstop")
        {
            sendCommand("stop", "", "");
        }
        else if (cmd == "tvload")
        {
            string url = llList2String(parts, 1);
            string title = llDumpList2String(llList2List(parts, 2, -1), " ");
            if (url == "") { llOwnerSay("Uso: tvload <url> <title>"); return; }
            sendCommand("change", url, title);
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200)
        {
            llOwnerSay("TV Sync: OK");
        }
        else
        {
            llOwnerSay("TV Sync error: " + (string)status + " " + body);
        }
    }

    touch_start(integer total_number)
    {
        llOwnerSay("Comandos: tvplay, tvpause, tvstop, tvload <url> <title>");
    }
}
