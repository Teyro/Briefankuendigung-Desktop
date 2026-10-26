/*
 * Symbol im Panel (oder kleine Kachel): Briefumschlag, dazu die Zahl der Briefe und Pakete,
 * die unterwegs sind – heute Angekündigtes hervorgehoben.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

MouseArea {
    id: kompakt

    property int anzahl: 0
    property int heute: 0
    property bool zeigeAnzahl: true
    property bool fehler: false
    property bool horizontal: true
    property bool aufDemSchreibtisch: false
    property bool paket: false
    readonly property int symbolGroesse: aufDemSchreibtisch
        ? Math.min(width, height) * 0.7
        : Math.min(Kirigami.Units.iconSizes.smallMedium, Math.min(width, height))

    Layout.minimumWidth: !aufDemSchreibtisch && horizontal ? symbolGroesse + Kirigami.Units.smallSpacing * 2 : -1
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: !aufDemSchreibtisch && !horizontal ? symbolGroesse + Kirigami.Units.smallSpacing * 2 : -1
    Layout.preferredHeight: Layout.minimumHeight

    signal geklickt()

    hoverEnabled: true
    onClicked: geklickt()

    Kirigami.Icon {
        id: symbol
        anchors.centerIn: parent
        width: kompakt.symbolGroesse
        height: width
        source: kompakt.paket ? "package-x-generic" : kompakt.heute > 0 ? "mail-unread-new" : kompakt.anzahl > 0 ? "mail-unread" : "mail-read"
        active: kompakt.containsMouse
        opacity: kompakt.fehler ? 0.5 : 1
    }

    // Anzahl als Abzeichen (wie bei den Benachrichtigungen)
    Rectangle {
        visible: kompakt.zeigeAnzahl && kompakt.anzahl > 0
        anchors.right: symbol.right
        anchors.bottom: symbol.bottom
        anchors.rightMargin: -Math.round(width / 4)
        anchors.bottomMargin: -Math.round(height / 5)
        width: Math.max(height, zahl.implicitWidth + Kirigami.Units.smallSpacing)
        height: Math.max(10, Math.round(kompakt.symbolGroesse * 0.5))
        radius: height / 2
        color: kompakt.heute > 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
        border.color: Kirigami.Theme.backgroundColor
        border.width: 1

        PC3.Label {
            id: zahl
            anchors.centerIn: parent
            text: kompakt.anzahl > 99 ? "99+" : kompakt.anzahl
            font.pixelSize: Math.max(7, parent.height * 0.72)
            font.weight: Font.Bold
            color: Kirigami.Theme.highlightedTextColor
        }
    }
}
