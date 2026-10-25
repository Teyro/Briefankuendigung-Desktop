/*
 * Verbindung zu Home Assistant: holt Briefe und Pakete der Integration „Briefankündigung“,
 * lädt die Umschlagbilder (mit Token, als data:-Adresse), markiert „Angekommen“ und lässt
 * Home Assistant auf Wunsch sofort ins Postfach schauen.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import "logik.js" as Logik

Item {
    id: ha

    // --- Einstellungen (von main.qml) ---
    property string adresse: ""
    property string token: ""
    property string konto: ""          // "" = alle Postfächer
    property int minuten: 10           // so oft neu laden (zusätzlich kurz nach jedem Abruf in Home Assistant)

    // --- Zustand ---
    property var post: null            // Antwort von /api/briefankuendigung/briefe
    property var bilder: ({})          // Brief-ID → data:-Adresse
    property bool laedt: false
    property bool nachsehen: false     // Home Assistant liest gerade das Postfach
    property string fehler: ""
    property bool abgelehnt: false     // Token abgelehnt: nicht weiter fragen (sonst sperrt Home Assistant die IP)
    property bool fehltIntegration: false
    property double stand: 0           // wann zuletzt geladen

    readonly property string basis: Logik.adresse(adresse)
    readonly property bool eingerichtet: basis !== "" && token.trim() !== ""
    readonly property var briefe: post ? Logik.nurKonto(post.briefe, konto) : []
    readonly property var konten: post ? post.konten : []
    readonly property bool mehrereKonten: konto === "" && konten.length > 1

    signal meldung(string text)

    function anfrage(methode, pfad, daten, fertig) {
        if (!eingerichtet) return;
        const xhr = new XMLHttpRequest();
        xhr.open(methode, basis + pfad);
        xhr.setRequestHeader("Authorization", "Bearer " + token.trim());
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 20000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status >= 200 && xhr.status < 300) {
                let antwort = null;
                try { antwort = xhr.responseText ? JSON.parse(xhr.responseText) : null; } catch (e) { antwort = null; }
                fertig(antwort, null, xhr.status);
            } else {
                let text;
                if (xhr.status === 401 || xhr.status === 403) text = i18n("Zugriff verweigert – bitte den Token prüfen.");
                else if (xhr.status === 404) text = i18n("Die Integration „Briefankündigung“ fehlt in Home Assistant (HACS).");
                else if (xhr.status === 0) text = i18n("Home Assistant ist nicht erreichbar (%1).", basis);
                else text = i18n("Fehler %1 von Home Assistant.", xhr.status);
                fertig(null, text, xhr.status);
            }
        };
        xhr.send(daten === null || daten === undefined ? null : JSON.stringify(daten));
    }

    function laden() {
        if (!eingerichtet || abgelehnt) return;
        laedt = true;
        anfrage("GET", "/api/briefankuendigung/briefe", null, function (antwort, text, status) {
            laedt = false;
            stand = Date.now();
            if (status === 401 || status === 403) abgelehnt = true;
            fehltIntegration = status === 404;
            if (text || !antwort || !Array.isArray(antwort.briefe)) { fehler = text || i18n("Unerwartete Antwort von Home Assistant."); return; }
            fehler = "";
            post = antwort;
            for (const b of antwort.briefe.slice(0, 30)) if (b.bild && !bilder[b.id]) bildLaden(b.id);
            if (nachsehen && antwort.konten.every(k => !k.laeuft) && antwort.stand > nachsehenSeit) nachsehen = false;
            planen();
        });
    }

    function bildLaden(id) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", basis + "/api/briefankuendigung/bild/" + id);
        xhr.setRequestHeader("Authorization", "Bearer " + token.trim());
        xhr.responseType = "arraybuffer";
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200 || !xhr.response) return;
            const neu = Object.assign({}, bilder);
            neu[id] = Logik.bildAdresse(new Uint8Array(xhr.response));
            bilder = neu;
        };
        xhr.send();
    }

    /** „Angekommen“ (gilt auf allen Geräten) – sofort anzeigen, dann speichern */
    function abhaken(id, erledigt) {
        if (post) {
            const neu = Object.assign({}, post);
            neu.briefe = post.briefe.map(b => b.id === id ? Object.assign({}, b, { erledigt: erledigt }) : b);
            post = neu;
        }
        anfrage("POST", "/api/briefankuendigung/erledigt", { id: id, erledigt: erledigt }, function (antwort, text) {
            if (text) { meldung(text); laden(); }
        });
    }

    /** Home Assistant jetzt ins Postfach schauen lassen und ein paar Mal nachladen */
    property double nachsehenSeit: 0
    function jetztNachsehen() {
        nachsehen = true;
        nachsehenSeit = post ? post.stand : 0;
        anfrage("POST", "/api/briefankuendigung/abrufen" + (konto ? "?konto=" + encodeURIComponent(konto) : ""), {}, function (antwort, text) {
            if (text) { nachsehen = false; meldung(text); return; }
            nachladen.zaehler = 0;
            nachladen.restart();
        });
    }
    Timer {
        id: nachladen
        property int zaehler: 0
        interval: 5000
        repeat: true
        onTriggered: { ha.laden(); if (++zaehler >= 8 || !ha.nachsehen) { stop(); ha.nachsehen = false; } }
    }

    /** Neu laden: regelmäßig und kurz nach dem nächsten Abruf in Home Assistant (2:00, 5:00 …) */
    function planen() {
        const n = Logik.naechsterAbruf(konten);
        const regel = Math.max(1, minuten) * 60000;
        const bisAbruf = n ? n + 3 * 60000 - Date.now() : regel;
        regelmaessig.interval = Math.max(30000, Math.min(regel, bisAbruf > 0 ? bisAbruf : regel));
        regelmaessig.restart();
    }
    Timer { id: regelmaessig; interval: 600000; repeat: false; onTriggered: ha.laden() }

    function erneutVersuchen() { abgelehnt = false; laden(); }

    onBasisChanged: { post = null; bilder = {}; abgelehnt = false; Qt.callLater(laden); }
    onTokenChanged: { abgelehnt = false; Qt.callLater(laden); }
    onMinutenChanged: planen()
    Component.onCompleted: laden()
}
