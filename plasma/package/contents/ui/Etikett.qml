/*
 * Kleines farbiges Etikett wie „Heute“ oder „Wichtig“.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Rectangle {
    property alias text: beschriftung.text
    property color farbe: Kirigami.Theme.highlightColor

    implicitWidth: beschriftung.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: beschriftung.implicitHeight + 2
    radius: height / 2
    color: Qt.rgba(farbe.r, farbe.g, farbe.b, 0.18)

    PC3.Label {
        id: beschriftung
        anchors.centerIn: parent
        font: Kirigami.Theme.smallFont
        color: parent.farbe
    }
}
