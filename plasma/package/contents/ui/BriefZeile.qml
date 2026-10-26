/*
 * Eine Zeile der Liste: Umschlag (bzw. Symbol), Absender mit Etiketten, Datum/Stand, „Angekommen“.
 * Ein Klick klappt den Brief auf: Umschlag groß, Datum, Sendungsverfolgung.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

import "logik.js" as Logik

Item {
    id: zeile

    required property var ha
    property var brief
    property double jetzt: Date.now()
    property bool aufgeklappt: false
    signal umschalten()

    readonly property bool erledigt: Logik.erledigt(brief)
    readonly property bool paket: brief.art === "paket"
    readonly property string bild: ha.bilder[brief.id] || ""

    implicitHeight: spalte.implicitHeight + Kirigami.Units.smallSpacing * 2
    Accessible.role: Accessible.ListItem
    Accessible.name: (paket ? i18n("Paket von %1", Logik.absender(brief)) : i18n("Brief von %1", Logik.absender(brief))) + ", " + unterzeile.text

    HoverHandler { id: zeiger; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: zeile.umschalten() }
    PlasmaExtras.Highlight {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        hovered: true
        visible: zeiger.hovered || zeile.aufgeklappt
    }

    ColumnLayout {
        id: spalte
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing
        opacity: zeile.erledigt ? 0.6 : 1

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Umschlag {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.2
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                brief: zeile.brief
                bild: zeile.bild
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Etikett {
                        visible: (zeile.paket ? Logik.paketHeute(zeile.brief, zeile.jetzt) : Logik.gleicherTag(zeile.brief.datum, zeile.jetzt)) && !zeile.erledigt
                        text: i18n("Heute")
                        farbe: Kirigami.Theme.highlightColor
                    }
                    Etikett {
                        visible: zeile.brief.wichtig === true
                        text: i18n("Wichtig")
                        farbe: Kirigami.Theme.negativeTextColor
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: Logik.absender(zeile.brief)
                        textFormat: Text.PlainText
                        font.weight: zeile.erledigt ? Font.Normal : Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PaketFortschritt { visible: zeile.paket; brief: zeile.brief }
                    PC3.Label {
                        id: unterzeile
                        Layout.fillWidth: true
                        text: Logik.unterzeile(zeile.brief, zeile.jetzt, zeile.ha.mehrereKonten)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
            }

            PC3.ToolButton {
                visible: !(zeile.paket && zeile.brief.stand === "zugestellt")
                icon.name: zeile.erledigt ? "edit-undo" : "dialog-ok-apply"
                text: zeile.erledigt ? i18n("Doch nicht angekommen") : i18n("Angekommen")
                display: PC3.AbstractButton.IconOnly
                onClicked: zeile.ha.abhaken(zeile.brief.id, !zeile.erledigt)
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // Aufgeklappt: Umschlag groß, Datum, Sendungsverfolgung
        Umschlag {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(width * 0.6, Kirigami.Units.gridUnit * 16) : 0
            visible: zeile.aufgeklappt && zeile.bild !== ""
            brief: zeile.brief
            bild: zeile.bild
            gross: true
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: zeile.aufgeklappt && !!zeile.brief.status_text
            text: zeile.brief.status_text || ""
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            visible: zeile.aufgeklappt
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                Layout.fillWidth: true
                text: i18n("angekündigt %1", new Date(zeile.brief.datum).toLocaleString(Qt.locale(), Locale.ShortFormat))
                      + (zeile.brief.sendung ? " · " + i18n("Sendung %1", zeile.brief.sendung) : "")
                      + (zeile.brief.kundenkonto ? " · " + zeile.brief.kundenkonto : zeile.brief.konto_name ? " · " + zeile.brief.konto_name : "")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                wrapMode: Text.Wrap
            }
            PC3.Button {
                visible: !!zeile.brief.manuell
                icon.name: "edit-delete"
                text: i18n("Entfernen")
                onClicked: zeile.ha.sendungEntfernen(zeile.brief.id)
            }
            PC3.Button {
                visible: !!(zeile.brief.verfolgen || zeile.brief.sendung)
                icon.name: "find-location"
                text: i18n("Verfolgen")
                onClicked: Qt.openUrlExternally(zeile.brief.verfolgen || Logik.dhlAdresse(zeile.brief.sendung))
            }
        }
    }
}
