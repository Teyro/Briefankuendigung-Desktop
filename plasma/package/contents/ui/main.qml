/*
 * Briefankündigung für Plasma 6: angekündigte Briefe und Pakete aus Home Assistant
 * (Integration „Briefankündigung“) – als frei skalierbare Kachel auf dem Schreibtisch
 * oder im Panel mit Liste im Popup.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "logik.js" as Logik

PlasmoidItem {
    id: root

    readonly property bool aufDemSchreibtisch: Plasmoid.formFactor === PlasmaCore.Types.Planar || Plasmoid.formFactor === PlasmaCore.Types.MediaCenter

    Verbindung {
        id: verbindung
        adresse: Plasmoid.configuration.adresse
        token: Plasmoid.configuration.token
        konto: Plasmoid.configuration.konto
        minuten: Plasmoid.configuration.minuten
    }

    readonly property var gruppen: Logik.gruppen(verbindung.briefe, Date.now())

    // Gemeinsame Logik übersetzen (Platzhalter %1 … bleiben stehen, die Logik setzt sie ein)
    function uebersetze(text) {
        const n = (text.match(/%\d/g) || []).length;
        return n === 0 ? i18n(text) : n === 1 ? i18n(text, "%1") : i18n(text, "%1", "%2");
    }

    // Noch nicht eingerichtet: Zugang aus Home Assistant ToolBox übernehmen, falls vorhanden
    readonly property string toolboxBefehl: "cat \"$HOME/.config/homeassistanttoolbox/instanzen.json\" 2>/dev/null"
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: (quelle, daten) => {
            disconnectSource(quelle);
            const z = Logik.toolboxZugang((daten.stdout || "").trim());
            if (z && !verbindung.eingerichtet) {
                Plasmoid.configuration.adresse = z.adresse;
                Plasmoid.configuration.token = z.token;
            }
        }
    }
    Component.onCompleted: {
        Logik.sprache(uebersetze);
        if (!verbindung.eingerichtet) shell.connectSource(toolboxBefehl);
    }

    // ---- Updates (nur einmal je Plasma: im Panel-Widget bzw. in der ersten Kachel ist egal – kpackagetool ersetzt für alle)
    Aktualisierer {
        id: updater
        aktuelleVersion: Plasmoid.metaData.version
        automatisch: Plasmoid.configuration.updatesSuchen
    }

    Plasmoid.icon: root.gruppen.heute.length ? "mail-unread-new" : root.gruppen.offen.length ? "mail-unread" : "mail-read"
    Plasmoid.status: root.gruppen.offen.length ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    toolTipMainText: verbindung.post ? Logik.titel(root.gruppen.offen) : i18n("Briefankündigung")
    toolTipSubText: {
        if (!verbindung.eingerichtet) return i18n("Noch nicht eingerichtet – Rechtsklick → Einrichten");
        if (verbindung.fehler) return verbindung.fehler;
        return root.gruppen.offen.slice(0, 5).map(b => (b.wichtig ? "⚠ " : "") + Logik.absender(b) + " – " + Logik.unterzeile(b, Date.now(), false)).join("\n");
    }

    // Kleine Kachel: nur Symbol mit Zahl, Klick öffnet die Liste
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 8

    compactRepresentation: KompaktAnsicht {
        anzahl: root.gruppen.offen.length
        heute: root.gruppen.heute.length
        zeigeAnzahl: Plasmoid.configuration.zeigeAnzahl
        fehler: verbindung.fehler !== "" && !verbindung.post
        horizontal: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
        aufDemSchreibtisch: root.aufDemSchreibtisch
        onGeklickt: root.expanded = !root.expanded
    }

    fullRepresentation: Hauptansicht {
        ha: verbindung
        aktualisierer: updater
        imPopup: !root.aufDemSchreibtisch || root.expanded
        modus: root.aufDemSchreibtisch && !root.expanded ? Plasmoid.configuration.modusKachel : Plasmoid.configuration.modusPopup
        automatisch: Plasmoid.configuration.automatisch
        onEinrichten: Plasmoid.internalAction("configure").trigger()
        onModusGewechselt: (m) => {
            if (root.aufDemSchreibtisch && !root.expanded) Plasmoid.configuration.modusKachel = m;
            else Plasmoid.configuration.modusPopup = m;
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Jetzt nachsehen")
            icon.name: "view-refresh"
            enabled: verbindung.eingerichtet && !verbindung.nachsehen
            onTriggered: verbindung.jetztNachsehen()
        },
        PlasmaCore.Action {
            text: i18n("Home Assistant öffnen")
            icon.name: "internet-web-browser"
            enabled: verbindung.basis !== ""
            onTriggered: Qt.openUrlExternally(verbindung.basis)
        }
    ]
}
