/*
 * Hauptansicht – als Kachel auf dem Schreibtisch und im Popup aus dem Panel:
 * Kopf (Anzahl, Stand, Karten/Liste, Nachsehen, Menü), darunter Karten oder Liste.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

Item {
    id: haupt
    objectName: "hauptansicht"

    required property var ha
    property var aktualisierer: null
    property string modus: "karten"          // "karten" | "liste"
    property bool automatisch: true
    property bool imPopup: false
    property bool zeigeNeuigkeiten: false
    signal einrichten()
    signal modusGewechselt(string modus)
    // "alles" (Reiter Briefe · Pakete), "briefe" oder "pakete" – so lässt sich eine eigene Pakete-Kachel anlegen
    property string inhalt: "alles"
    property string bereich: "briefe"
    readonly property bool paketAnsicht: inhalt === "pakete" || (inhalt === "alles" && bereich === "pakete")
    property bool formular: false

    property double jetzt: Date.now()
    Timer { interval: 60000; running: haupt.visible; repeat: true; onTriggered: haupt.jetzt = Date.now() }

    readonly property var gruppen: paketAnsicht ? Logik.paketGruppen(ha.briefe, jetzt) : Logik.gruppen(Logik.nurArt(ha.briefe, inhalt === "briefe" || inhalt === "alles" ? "briefe" : "alles"), jetzt)
    readonly property var paketGruppen: Logik.paketGruppen(ha.briefe, jetzt)
    readonly property var briefGruppen: Logik.gruppen(Logik.nurArt(ha.briefe, "briefe"), jetzt)
    // Schmale oder flache Kachel: nur das Nötigste im Kopf
    readonly property bool eng: width < Kirigami.Units.gridUnit * 14
    readonly property bool flach: height < Kirigami.Units.gridUnit * 9

    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.minimumHeight: Kirigami.Units.gridUnit * 8
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------- Kopf
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: haupt.imPopup ? Kirigami.Units.smallSpacing : 0
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: !haupt.zeigeNeuigkeiten

            Kirigami.Icon {
                Layout.preferredWidth: haupt.eng ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Layout.preferredWidth
                source: haupt.paketAnsicht ? "package-x-generic" : haupt.gruppen.heute.length ? "mail-unread-new" : haupt.gruppen.offen.length ? "mail-unread" : "mail-read"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: haupt.eng ? 4 : 3
                    text: !haupt.ha.post ? i18n("Briefankündigung") : haupt.paketAnsicht ? Logik.paketTitel(haupt.gruppen.offen) : Logik.titel(haupt.gruppen.offen)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text !== "" && !haupt.flach
                    text: {
                        if (!haupt.ha.post) return "";
                        const teile = [];
                        if (haupt.gruppen.heute.length) teile.push(i18n("%1 heute", haupt.gruppen.heute.length));
                        if (haupt.ha.post.stand) teile.push(i18n("gelesen %1", Logik.vor(haupt.ha.post.stand, haupt.jetzt)));
                        const n = Logik.naechsterAbruf(haupt.ha.konten);
                        if (n && !haupt.eng) teile.push(i18n("nächstes Mal %1", new Date(n).toLocaleTimeString(Qt.locale(), "hh:mm")));
                        return teile.join(" · ");
                    }
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
            PC3.ToolButton {
                visible: !!haupt.ha.post && haupt.gruppen.offen.length > 0
                icon.name: haupt.modus === "karten" ? "view-list-details" : "view-preview"
                text: haupt.modus === "karten" ? i18n("Als Liste") : i18n("Als Karten")
                display: PC3.AbstractButton.IconOnly
                onClicked: haupt.modusGewechselt(haupt.modus === "karten" ? "liste" : "karten")
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PC3.ToolButton {
                visible: haupt.ha.eingerichtet && !haupt.ha.fehltIntegration
                icon.name: "view-refresh"
                text: i18n("Jetzt nachsehen")
                display: PC3.AbstractButton.IconOnly
                enabled: !haupt.ha.nachsehen
                onClicked: haupt.ha.jetztNachsehen()
                PC3.ToolTip.text: i18n("Home Assistant jetzt ins Postfach schauen lassen")
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                PC3.BusyIndicator {
                    anchors.fill: parent
                    running: haupt.ha.nachsehen
                    visible: running
                }
            }
            PC3.ToolButton {
                visible: haupt.paketAnsicht && !!haupt.ha.post
                icon.name: "list-add"
                text: i18n("Sendung hinzufügen")
                display: PC3.AbstractButton.IconOnly
                checkable: true
                checked: haupt.formular
                onClicked: haupt.formular = !haupt.formular
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PC3.ToolButton {
                id: menueKnopf
                icon.name: "overflow-menu"
                text: i18n("Mehr")
                display: PC3.AbstractButton.IconOnly
                down: menue.opened
                onClicked: menue.opened ? menue.close() : menue.popup(menueKnopf, 0, menueKnopf.height)
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered && !menue.opened
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
            PC3.Menu {
                id: menue
                PC3.MenuItem {
                    text: i18n("Neu laden")
                    icon.name: "view-refresh"
                    enabled: haupt.ha.eingerichtet
                    onTriggered: haupt.ha.erneutVersuchen()
                }
                PC3.MenuItem {
                    text: i18n("Home Assistant öffnen")
                    icon.name: "internet-web-browser-symbolic"
                    enabled: haupt.ha.basis !== ""
                    onTriggered: Qt.openUrlExternally(haupt.ha.basis)
                }
                PC3.MenuSeparator {}
                PC3.MenuItem {
                    text: haupt.aktualisierer && haupt.aktualisierer.update ? i18n("Update auf %1 …", haupt.aktualisierer.update.version) : i18n("Was ist neu?")
                    icon.name: haupt.aktualisierer && haupt.aktualisierer.update ? "update-none" : "documentinfo"
                    enabled: haupt.aktualisierer !== null
                    onTriggered: { if (haupt.aktualisierer.alleNotizen.length === 0) haupt.aktualisierer.pruefen(); haupt.zeigeNeuigkeiten = true; }
                }
                PC3.MenuItem {
                    text: i18n("Nach Updates suchen")
                    icon.name: "system-software-update"
                    enabled: haupt.aktualisierer !== null && haupt.aktualisierer.status !== "suche"
                    onTriggered: { haupt.aktualisierer.pruefen(); haupt.zeigeNeuigkeiten = true; }
                }
                PC3.MenuItem {
                    text: i18n("Einstellungen …")
                    icon.name: "configure"
                    onTriggered: haupt.einrichten()
                }
            }
        }

        // Reiter Briefe · Pakete (nur bei Inhalt „alles“)
        PC3.TabBar {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: haupt.inhalt === "alles" && !!haupt.ha.post && !haupt.zeigeNeuigkeiten
            currentIndex: haupt.bereich === "pakete" ? 1 : 0
            PC3.TabButton {
                text: haupt.briefGruppen.offen.length ? i18n("Briefe (%1)", haupt.briefGruppen.offen.length) : i18n("Briefe")
                icon.name: "mail-message"
                onClicked: haupt.bereich = "briefe"
            }
            PC3.TabButton {
                text: haupt.paketGruppen.offen.length ? i18n("Pakete (%1)", haupt.paketGruppen.offen.length) : i18n("Pakete")
                icon.name: "package-x-generic"
                onClicked: haupt.bereich = "pakete"
            }
        }

        SendungFormular {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: haupt.formular && haupt.paketAnsicht && !haupt.zeigeNeuigkeiten
            ha: haupt.ha
            onFertig: haupt.formular = false
        }

        // Update verfügbar
        PlasmaExtras.Highlight {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !!haupt.aktualisierer && !!haupt.aktualisierer.update && !haupt.zeigeNeuigkeiten && !haupt.flach
            implicitHeight: updateZeile.implicitHeight + Kirigami.Units.smallSpacing * 2
            RowLayout {
                id: updateZeile
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                PC3.Label {
                    Layout.fillWidth: true
                    text: parent.parent.visible ? i18n("Version %1 ist verfügbar.", haupt.aktualisierer.update.version) : ""
                    elide: Text.ElideRight
                }
                PC3.Button {
                    text: i18n("Ansehen")
                    onClicked: haupt.zeigeNeuigkeiten = true
                }
            }
        }

        // Fehler, solange schon Briefe da sind (sonst als Platzhalter unten)
        PC3.Label {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !!haupt.ha.post && (haupt.ha.fehler !== "" || (haupt.ha.post.fehler || "") !== "") && !haupt.zeigeNeuigkeiten
            text: haupt.ha.fehler || i18n("Postfach: %1", haupt.ha.post ? haupt.ha.post.fehler : "")
            color: Kirigami.Theme.negativeTextColor
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // ---------------------------------------------------------------- Inhalt
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Neuigkeiten {
                anchors.fill: parent
                visible: haupt.zeigeNeuigkeiten && haupt.aktualisierer !== null
                aktualisierer: haupt.aktualisierer
                onSchliessen: haupt.zeigeNeuigkeiten = false
            }

            Hinweis {
                anchors.fill: parent
                visible: !haupt.zeigeNeuigkeiten && !haupt.ha.eingerichtet
                symbol: "mail-message"
                text: i18n("Noch nicht eingerichtet")
                erklaerung: i18n("Adresse von Home Assistant und ein Token eintragen – die Integration „Briefankündigung“ liefert die Briefe.")
                knopfText: i18n("Einrichten …")
                knopfSymbol: "configure"
                onGeklickt: haupt.einrichten()
            }

            Hinweis {
                anchors.fill: parent
                visible: !haupt.zeigeNeuigkeiten && haupt.ha.eingerichtet && !haupt.ha.post && haupt.ha.fehler !== ""
                symbol: haupt.ha.fehltIntegration ? "package-x-generic" : "network-disconnect"
                text: haupt.ha.fehltIntegration ? i18n("Integration fehlt") : i18n("Keine Verbindung")
                erklaerung: haupt.ha.fehler
                knopfText: haupt.ha.fehltIntegration ? i18n("Integration ansehen") : i18n("Erneut versuchen")
                knopfSymbol: haupt.ha.fehltIntegration ? "internet-web-browser-symbolic" : "view-refresh"
                onGeklickt: haupt.ha.fehltIntegration ? Qt.openUrlExternally("https://github.com/Teyro/Briefankuendigung-HA") : haupt.ha.erneutVersuchen()
            }

            PC3.BusyIndicator {
                anchors.centerIn: parent
                visible: !haupt.zeigeNeuigkeiten && haupt.ha.eingerichtet && !haupt.ha.post && haupt.ha.fehler === ""
                running: visible
            }

            KartenAnsicht {
                anchors.fill: parent
                visible: !haupt.zeigeNeuigkeiten && !!haupt.ha.post && haupt.modus === "karten" && haupt.gruppen.offen.length > 0
                ha: haupt.ha
                briefe: haupt.gruppen.offen
                jetzt: haupt.jetzt
                automatisch: haupt.automatisch
            }

            // Karten, aber nichts unterwegs: kurz und freundlich
            Hinweis {
                anchors.fill: parent
                visible: !haupt.zeigeNeuigkeiten && !!haupt.ha.post && haupt.modus === "karten" && haupt.gruppen.offen.length === 0
                symbol: haupt.paketAnsicht ? "package-x-generic" : "mail-mark-read"
                text: haupt.paketAnsicht ? i18n("Keine Pakete unterwegs") : i18n("Keine Post unterwegs")
                erklaerung: !haupt.gruppen.angekommen.length ? ""
                    : i18n("Zuletzt: %1 (%2)", Logik.absender(haupt.gruppen.angekommen[0]), Logik.datum(haupt.gruppen.angekommen[0].datum, haupt.jetzt))
            }

            ListenAnsicht {
                anchors.fill: parent
                visible: !haupt.zeigeNeuigkeiten && !!haupt.ha.post && haupt.modus === "liste"
                ha: haupt.ha
                jetzt: haupt.jetzt
                gruppen: haupt.gruppen
                angekommenText: haupt.paketAnsicht ? i18n("Zugestellt") : i18n("Angekommen")
                leerText: haupt.paketAnsicht ? i18n("Keine Pakete") : i18n("Keine Post angekündigt")
                leerErklaerung: haupt.paketAnsicht ? i18n("Pakete von DHL, Hermes, DPD und Amazon erscheinen hier, sobald eine Mail dazu kommt – oder über ＋ mit der Sendungsnummer.")
                                                   : i18n("Sobald die Deutsche Post einen Brief ankündigt, erscheint er hier mit Bild des Umschlags.")
            }
        }
    }
}
