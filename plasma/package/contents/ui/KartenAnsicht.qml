/*
 * Karten zum Durchblättern: je Brief der Umschlag groß, Absender und Stand. Wischen, Mausrad,
 * Pfeiltasten oder ‹ › blättern; auf Wunsch blättert sie von selbst weiter.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

import "logik.js" as Logik

ColumnLayout {
    id: karten
    objectName: "kartenAnsicht"

    required property var ha
    property var briefe: []
    property double jetzt: Date.now()
    property bool automatisch: true
    property alias index: band.currentIndex
    // Breite, flache Kachel: Umschlag links, Angaben rechts
    readonly property bool quer: band.width > band.height * 2.2

    spacing: Kirigami.Units.smallSpacing
    focus: true
    Keys.onLeftPressed: weiter(-1)
    Keys.onRightPressed: weiter(1)

    function weiter(schritt) {
        if (briefe.length < 2) return;
        band.currentIndex = Logik.blaettern(band.currentIndex, schritt, briefe.length);
        pause.restart();
    }

    // Von selbst weiterblättern – nicht, solange die Maus darüber ist, und nach Bedienung eine Weile Pause
    Timer {
        interval: 9000
        repeat: true
        running: karten.automatisch && karten.visible && karten.briefe.length > 1 && !ueber.hovered && !pause.running
        onTriggered: band.currentIndex = Logik.blaettern(band.currentIndex, 1, karten.briefe.length)
    }
    Timer { id: pause; interval: 30000 }
    HoverHandler { id: ueber }

    ListView {
        id: band
        Layout.fillWidth: true
        Layout.fillHeight: true
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Kirigami.Units.longDuration
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: karten.briefe
        onMovementEnded: pause.restart()

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
                if (Math.abs(d) >= 60) karten.weiter(d < 0 ? 1 : -1);
            }
        }

        delegate: Item {
            id: karte
            required property var modelData
            required property int index
            width: band.width
            height: band.height
            readonly property var b: modelData
            readonly property bool erledigt: Logik.erledigt(b)

            GridLayout {
                id: gitter
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                columns: karten.quer ? 2 : 1
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.largeSpacing

                Umschlag {
                    Layout.fillWidth: !karten.quer
                    Layout.fillHeight: true
                    Layout.preferredWidth: karten.quer ? Math.min(gitter.height * 1.6, gitter.width * 0.45) : -1
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 2
                    brief: karte.b
                    bild: karten.ha.bilder[karte.b.id] || ""
                    gross: true
                    TapHandler { onTapped: karten.weiter(1) }
                }

                ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: karten.quer ? Qt.AlignVCenter : Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Etikett {
                        visible: Logik.gleicherTag(karte.b.datum, karten.jetzt) && !karte.erledigt
                        text: i18n("Heute")
                    }
                    Etikett {
                        visible: karte.b.wichtig === true
                        text: i18n("Wichtig")
                        farbe: Kirigami.Theme.negativeTextColor
                    }
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: Logik.absender(karte.b)
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PaketFortschritt { visible: karte.b.art === "paket"; brief: karte.b; hoehe: 7 }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: Logik.unterzeile(karte.b, karten.jetzt, karten.ha.mehrereKonten)
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                    PC3.ToolButton {
                        visible: !!karte.b.sendung
                        icon.name: "find-location"
                        text: i18n("Verfolgen")
                        display: PC3.AbstractButton.IconOnly
                        onClicked: Qt.openUrlExternally(Logik.dhlAdresse(karte.b.sendung))
                        PC3.ToolTip.text: text
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    PC3.ToolButton {
                        visible: !(karte.b.art === "paket" && karte.b.stand === "zugestellt")
                        icon.name: karte.erledigt ? "edit-undo" : "dialog-ok-apply"
                        text: karte.erledigt ? i18n("Doch nicht angekommen") : i18n("Angekommen")
                        display: PC3.AbstractButton.IconOnly
                        onClicked: karten.ha.abhaken(karte.b.id, !karte.erledigt)
                        PC3.ToolTip.text: text
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
                }
            }
        }
    }

    // ‹ ● ● ○ ›
    RowLayout {
        Layout.fillWidth: true
        visible: karten.briefe.length > 1
        spacing: 0
        PC3.ToolButton {
            icon.name: karten.LayoutMirroring.enabled ? "go-next" : "go-previous"
            text: i18n("Vorheriger Brief")
            display: PC3.AbstractButton.IconOnly
            onClicked: karten.weiter(-1)
        }
        Item { Layout.fillWidth: true }
        PC3.PageIndicator {
            count: Math.min(karten.briefe.length, 12)
            currentIndex: Math.min(band.currentIndex, 11)
            interactive: true
            onCurrentIndexChanged: if (currentIndex !== band.currentIndex && currentIndex < 11) { band.currentIndex = currentIndex; pause.restart(); }
        }
        Item { Layout.fillWidth: true }
        PC3.ToolButton {
            icon.name: karten.LayoutMirroring.enabled ? "go-previous" : "go-next"
            text: i18n("Nächster Brief")
            display: PC3.AbstractButton.IconOnly
            onClicked: karten.weiter(1)
        }
    }
}
