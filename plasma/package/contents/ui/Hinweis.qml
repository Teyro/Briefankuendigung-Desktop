/*
 * Hinweis in der Mitte (wie PlasmaExtras.PlaceholderMessage), passt sich aber kleinen Kacheln an:
 * Symbol und Erklärung nur, wenn Platz ist.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: hinweis

    property string symbol: ""
    property string text: ""
    property string erklaerung: ""
    property string knopfText: ""
    property string knopfSymbol: ""
    signal geklickt()

    readonly property bool platz: height > Kirigami.Units.gridUnit * 9

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 20)
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(Kirigami.Units.iconSizes.huge, hinweis.height / 3)
            Layout.preferredHeight: Layout.preferredWidth
            visible: hinweis.symbol !== "" && hinweis.platz
            source: hinweis.symbol
            opacity: 0.6
        }
        Kirigami.Heading {
            Layout.fillWidth: true
            level: 3
            text: hinweis.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            opacity: 0.75
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: hinweis.erklaerung !== "" && hinweis.height > Kirigami.Units.gridUnit * 6
            text: hinweis.erklaerung
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: hinweis.platz ? 4 : 2
            elide: Text.ElideRight
            color: Kirigami.Theme.disabledTextColor
        }
        PC3.Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: hinweis.knopfText !== ""
            text: hinweis.knopfText
            icon.name: hinweis.knopfSymbol
            onClicked: hinweis.geklickt()
        }
    }
}
