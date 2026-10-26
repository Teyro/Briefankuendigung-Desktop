/*
 * Liste: Heute · Noch unterwegs · Angekommen (je auf- und zuklappbar).
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

PC3.ScrollView {
    id: liste
    objectName: "listenAnsicht"

    required property var ha
    property double jetzt: Date.now()
    property var gruppen: Logik.gruppen(ha.briefe, jetzt)
    property string angekommenText: i18n("Angekommen")
    property string leerText: i18n("Keine Post angekündigt")
    property string leerErklaerung: i18n("Sobald die Deutsche Post einen Brief ankündigt, erscheint er hier mit Bild des Umschlags.")

    property bool heuteOffen: true
    property bool unterwegsOffen: true
    property bool angekommenOffen: false
    property string offen: ""          // aufgeklappter Brief

    contentWidth: availableWidth
    PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

    ColumnLayout {
        width: liste.availableWidth
        spacing: 0

        KlappKopf {
            Layout.fillWidth: true
            visible: liste.gruppen.heute.length > 0
            text: i18n("Heute")
            anzahl: liste.gruppen.heute.length
            offen: liste.heuteOffen
            onUmschalten: liste.heuteOffen = !liste.heuteOffen
        }
        Repeater {
            model: liste.heuteOffen ? liste.gruppen.heute : []
            delegate: zeileKomponente
        }

        KlappKopf {
            Layout.fillWidth: true
            visible: liste.gruppen.unterwegs.length > 0
            text: i18n("Noch unterwegs")
            anzahl: liste.gruppen.unterwegs.length
            offen: liste.unterwegsOffen
            onUmschalten: liste.unterwegsOffen = !liste.unterwegsOffen
        }
        Repeater {
            model: liste.unterwegsOffen ? liste.gruppen.unterwegs : []
            delegate: zeileKomponente
        }

        KlappKopf {
            Layout.fillWidth: true
            visible: liste.gruppen.angekommen.length > 0
            text: liste.angekommenText
            anzahl: liste.gruppen.angekommen.length
            offen: liste.angekommenOffen
            onUmschalten: liste.angekommenOffen = !liste.angekommenOffen
        }
        Repeater {
            model: liste.angekommenOffen ? liste.gruppen.angekommen : []
            delegate: zeileKomponente
        }

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.gridUnit
            visible: !!liste.ha.post && liste.gruppen.offen.length === 0 && liste.gruppen.angekommen.length === 0
            iconName: "mail-mark-read"
            text: liste.leerText
            explanation: liste.leerErklaerung
        }
    }

    Component {
        id: zeileKomponente
        BriefZeile {
            required property var modelData
            Layout.fillWidth: true
            ha: liste.ha
            brief: modelData
            jetzt: liste.jetzt
            aufgeklappt: liste.offen === modelData.id
            onUmschalten: liste.offen = aufgeklappt ? "" : modelData.id
        }
    }
}
