/*
 * Umschlag eines Briefs: das Bild von der Post auf Papier – ohne Bild ein Symbol
 * (Brief bzw. Paket) auf leicht getönter Fläche. Wichtige Briefe mit rotem Rand.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami

import "logik.js" as Logik

Rectangle {
    id: umschlag

    property var brief
    property string bild: ""
    property bool gross: false

    readonly property bool wichtig: !!brief && brief.wichtig === true && !brief.erledigt
    readonly property color tinte: Kirigami.Theme.textColor
    // Pakete: Fläche in der Farbe des Dienstes mit seinem Namen (DHL gelb, Hermes blau, DPD rot, Amazon dunkel)
    readonly property bool paket: !!brief && brief.art === "paket" && bild === ""
    readonly property var dienst: paket ? Logik.dienst(brief) : null

    radius: Kirigami.Units.cornerRadius
    color: paket ? dienst.farbe : bild ? "#fbf9f3" : Qt.rgba(tinte.r, tinte.g, tinte.b, 0.06)
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
    Row {
        anchors.centerIn: parent
        visible: umschlag.paket
        spacing: Math.max(2, umschlag.height * 0.06)
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: umschlag.gross || umschlag.width > Kirigami.Units.gridUnit * 5
            width: Math.min(umschlag.height * 0.45, Kirigami.Units.iconSizes.huge)
            height: width
            source: "package-x-generic"
            color: umschlag.paket ? umschlag.dienst.schrift : "black"
            isMask: true
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: umschlag.paket ? umschlag.dienst.name : ""
            color: umschlag.paket ? umschlag.dienst.schrift : "black"
            font.bold: true
            font.italic: !!umschlag.brief && umschlag.brief.dienst === "dhl"
            font.pixelSize: Math.max(8, Math.min(umschlag.height * (umschlag.gross ? 0.22 : 0.34), umschlag.width / (text.length * 0.75 + 0.5)))
        }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * (umschlag.gross ? 0.42 : 0.6)
        height: width
        visible: umschlag.bild === "" && !umschlag.paket
        source: !umschlag.brief ? "mail-message" : umschlag.wichtig ? "mail-mark-important" : "mail-message"
        color: umschlag.wichtig ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        isMask: true
    }
}
