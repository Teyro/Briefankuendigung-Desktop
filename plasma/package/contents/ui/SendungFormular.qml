/*
 * Sendung von Hand hinzufügen: Nummer, Paketdienst (oder erkennen), Name.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

PlasmaExtras.Highlight {
    id: formular

    required property var ha
    signal fertig()

    property string fehler: ""
    property bool laeuft: false
    readonly property var dienste: ["", "dhl", "hermes", "dpd", "amazon"]
    readonly property string erkannt: Logik.dienstVonNummer(nummer.text)

    implicitHeight: spalte.implicitHeight + Kirigami.Units.largeSpacing * 2

    function senden() {
        if (!nummer.text.trim()) return;
        laeuft = true;
        fehler = "";
        ha.sendungHinzufuegen(nummer.text.trim(), dienste[dienst.currentIndex] || erkannt, name.text.trim(), function (text) {
            laeuft = false;
            fehler = text;
            if (!text) { nummer.text = ""; name.text = ""; dienst.currentIndex = 0; formular.fertig(); }
        });
    }

    ColumnLayout {
        id: spalte
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        PC3.Label {
            text: i18n("Sendung verfolgen")
            font.weight: Font.DemiBold
        }
        RowLayout {
            Layout.fillWidth: true
            PC3.TextField {
                id: nummer
                Layout.fillWidth: true
                placeholderText: i18n("Sendungs- oder Bestellnummer")
                onAccepted: formular.senden()
            }
            PC3.ComboBox {
                id: dienst
                model: [formular.erkannt ? i18n("Automatisch (%1)", Logik.DIENSTE[formular.erkannt].name) : i18n("Paketdienst …"), "DHL", "Hermes", "DPD", "Amazon"]
            }
        }
        RowLayout {
            Layout.fillWidth: true
            PC3.TextField {
                id: name
                Layout.fillWidth: true
                placeholderText: i18n("Name, z. B. „Neue Schuhe“ (optional)")
                onAccepted: formular.senden()
            }
            PC3.Button {
                icon.name: "list-add"
                text: i18n("Hinzufügen")
                enabled: nummer.text.trim() !== "" && !formular.laeuft && (dienst.currentIndex > 0 || formular.erkannt !== "")
                onClicked: formular.senden()
            }
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: formular.fehler !== "" || (nummer.text.trim() !== "" && dienst.currentIndex === 0 && formular.erkannt === "")
            text: formular.fehler || i18n("Bitte den Paketdienst wählen – die Nummer passt zu mehreren.")
            color: formular.fehler ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
        }
    }
}
