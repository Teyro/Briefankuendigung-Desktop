/*
 * Fortschritt eines Pakets: unterwegs · kommt heute · zugestellt.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick

import org.kde.kirigami as Kirigami

import "logik.js" as Logik

Row {
    id: fortschritt
    property var brief
    property real hoehe: 6
    spacing: 2
    Accessible.name: brief && brief.stand === "zugestellt" ? i18n("zugestellt") : brief && brief.stand === "heute" ? i18n("kommt heute") : i18n("unterwegs")
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: index === 0 ? fortschritt.hoehe : fortschritt.hoehe * 2.4
            height: fortschritt.hoehe
            radius: height / 2
            color: fortschritt.brief && index < Logik.paketStufe(fortschritt.brief) ? Kirigami.Theme.positiveTextColor
                 : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
        }
    }
}
