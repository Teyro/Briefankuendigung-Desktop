/*
 * Umschlag eines Briefs: das Bild von der Post auf Papier – ohne Bild ein Symbol
 * (Brief bzw. Paket) auf leicht getönter Fläche. Wichtige Briefe mit rotem Rand.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami

Rectangle {
    id: umschlag

    property var brief
    property string bild: ""
    property bool gross: false

    readonly property bool wichtig: !!brief && brief.wichtig === true && !brief.erledigt
    readonly property color tinte: Kirigami.Theme.textColor

    radius: Kirigami.Units.cornerRadius
    color: bild ? "#fbf9f3" : Qt.rgba(tinte.r, tinte.g, tinte.b, 0.06)
    border.width: wichtig ? 2 : 1
    border.color: wichtig ? Kirigami.Theme.negativeTextColor : Qt.rgba(tinte.r, tinte.g, tinte.b, 0.15)

    Image {
        anchors.fill: parent
        anchors.margins: umschlag.gross ? 6 : 2
        source: umschlag.bild
        visible: umschlag.bild !== ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * (umschlag.gross ? 0.42 : 0.6)
        height: width
        visible: umschlag.bild === ""
        source: !umschlag.brief ? "mail-message" : umschlag.brief.art === "paket" ? "package-x-generic" : umschlag.wichtig ? "mail-mark-important" : "mail-message"
        color: umschlag.wichtig ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        isMask: true
    }
}
