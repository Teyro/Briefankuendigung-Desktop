/*
 * Einstellungen: Home Assistant (Adresse, Token, Verbindung testen, aus der ToolBox übernehmen),
 * Postfach, Anzeige, Updates.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

import "logik.js" as Logik

KCM.SimpleKCM {
    id: seite

    property alias cfg_adresse: adresse.text
    property alias cfg_token: token.text
    property string cfg_konto
    property alias cfg_minuten: minuten.value
    property string cfg_modusKachel
    property string cfg_modusPopup
    property alias cfg_automatisch: automatisch.checked
    property alias cfg_zeigeAnzahl: zeigeAnzahl.checked
    property alias cfg_updatesSuchen: updatesSuchen.checked

    // Standardwerte (von Plasma für „Standard“ gesetzt)
    property string cfg_adresseDefault
    property string cfg_tokenDefault
    property string cfg_kontoDefault
    property int cfg_minutenDefault
    property string cfg_modusKachelDefault
    property string cfg_modusPopupDefault
    property bool cfg_automatischDefault
    property bool cfg_zeigeAnzahlDefault
    property bool cfg_updatesSuchenDefault

    property var konten: []
    property string testErgebnis: ""
    property bool testOk: false
    property bool testLaeuft: false
    property var toolbox: null

    function testen() {
        const basis = Logik.adresse(adresse.text);
        if (!basis || !token.text.trim()) { testErgebnis = i18n("Bitte Adresse und Token eintragen."); testOk = false; return; }
        testLaeuft = true;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", basis + "/api/briefankuendigung/briefe");
        xhr.setRequestHeader("Authorization", "Bearer " + token.text.trim());
        xhr.timeout = 15000;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            testLaeuft = false;
            testOk = xhr.status === 200;
            if (xhr.status === 200) {
                let a = null;
                try { a = JSON.parse(xhr.responseText); } catch (e) { a = null; }
                konten = a && Array.isArray(a.konten) ? a.konten : [];
                const n = a && Array.isArray(a.briefe) ? a.briefe.filter(b => !Logik.erledigt(b)).length : 0;
                testErgebnis = i18n("Verbunden – %1 Postfächer, %2 Sendungen unterwegs.", konten.length, n);
            } else if (xhr.status === 401 || xhr.status === 403) testErgebnis = i18n("Zugriff verweigert – bitte den Token prüfen.");
            else if (xhr.status === 404) testErgebnis = i18n("Die Integration „Briefankündigung“ fehlt in Home Assistant (HACS).");
            else if (xhr.status === 0) testErgebnis = i18n("Home Assistant ist nicht erreichbar (%1).", basis);
            else testErgebnis = i18n("Fehler %1 von Home Assistant.", xhr.status);
        };
        xhr.send();
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: ["cat \"$HOME/.config/homeassistanttoolbox/instanzen.json\" 2>/dev/null"]
        onNewData: (quelle, daten) => { disconnectSource(quelle); seite.toolbox = Logik.toolboxZugang((daten.stdout || "").trim()); }
    }

    Component.onCompleted: if (adresse.text && token.text) testen()

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Home Assistant")
        }
        QQC2.TextField {
            id: adresse
            Kirigami.FormData.label: i18n("Adresse:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: "https://homeassistant.local:8123"
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
        }
        Kirigami.PasswordField {
            id: token
            Kirigami.FormData.label: i18n("Token:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: i18n("Langlebiges Zugriffstoken")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("Token anlegen: in Home Assistant unten links auf den Namen → Sicherheit → „Langlebige Zugriffstoken“.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        RowLayout {
            QQC2.Button {
                icon.name: "network-connect"
                text: i18n("Verbindung testen")
                enabled: !seite.testLaeuft
                onClicked: seite.testen()
            }
            QQC2.Button {
                visible: seite.toolbox !== null
                icon.name: "edit-copy"
                text: i18n("Aus Home Assistant ToolBox übernehmen")
                onClicked: { adresse.text = seite.toolbox.adresse; token.text = seite.toolbox.token; seite.testen(); }
            }
        }
        QQC2.Label {
            visible: text !== ""
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: seite.testErgebnis
            wrapMode: Text.Wrap
            color: seite.testOk ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Anzeige")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Postfach:")
            readonly property var namen: [""].concat(seite.konten.map(k => k.name)).concat(seite.cfg_konto && seite.konten.every(k => k.name !== seite.cfg_konto) ? [seite.cfg_konto] : [])
            model: namen.map(n => n === "" ? i18n("Alle Postfächer") : n)
            currentIndex: Math.max(0, namen.indexOf(seite.cfg_konto))
            onActivated: (i) => seite.cfg_konto = namen[i]
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Auf dem Schreibtisch:")
            model: [i18n("Karten zum Durchblättern"), i18n("Liste")]
            currentIndex: seite.cfg_modusKachel === "liste" ? 1 : 0
            onActivated: (i) => seite.cfg_modusKachel = i === 1 ? "liste" : "karten"
        }
        QQC2.CheckBox {
            id: automatisch
            text: i18n("Karten von selbst weiterblättern")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Im Panel-Popup:")
            model: [i18n("Liste"), i18n("Karten zum Durchblättern")]
            currentIndex: seite.cfg_modusPopup === "karten" ? 1 : 0
            onActivated: (i) => seite.cfg_modusPopup = i === 1 ? "karten" : "liste"
        }
        QQC2.CheckBox {
            id: zeigeAnzahl
            text: i18n("Anzahl am Symbol zeigen")
        }
        QQC2.SpinBox {
            id: minuten
            Kirigami.FormData.label: i18n("Neu laden alle:")
            from: 1
            to: 120
            textFromValue: (v) => i18n("%1 min", v)
            valueFromText: (t) => parseInt(t, 10) || 10
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            text: i18n("Zusätzlich kurz nach jedem Blick der Integration ins Postfach (z. B. 2:00 und 5:00 Uhr).")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Updates")
        }
        QQC2.CheckBox {
            id: updatesSuchen
            text: i18n("Automatisch nach neuen Versionen suchen")
        }
        QQC2.Label {
            text: i18n("Version %1 · <a href=\"%2\">Quelltext auf GitHub</a>", Plasmoid.metaData.version, "https://github.com/Teyro/Briefankuendigung-Desktop")
            onLinkActivated: (l) => Qt.openUrlExternally(l)
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
