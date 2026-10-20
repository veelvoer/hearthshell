// qmllint disable
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The notification centre menu: everything that is waiting, Do not disturb, clear all.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    signal requestClose()
    readonly property var nf: shell ? shell.notifier : null
    readonly property var items: nf ? nf.history : []
    readonly property real wantedHeight: 62 + Math.max(110, Math.min(380, list.contentHeight)) + 16

    Text {
        x: 54; y: 15; text: "Notifications"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    // Do not disturb
    Rectangle {
        id: dnd
        anchors { right: clear.left; rightMargin: 8; top: parent.top; topMargin: 12 }
        height: 30; width: dndRow.width + 22; radius: 15
        color: root.nf && root.nf.dnd ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.25) : (dm.containsMouse ? main.card : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08))
        Behavior on color { ColorAnimation { duration: main.ms(150) } }
        Row {
            id: dndRow; anchors.centerIn: parent; spacing: 6
            Text { text: String.fromCodePoint(0xF009B); color: root.nf && root.nf.dnd ? main.accent : main.muted; anchors.verticalCenter: parent.verticalCenter
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 14 } }
            Text { text: "Quiet"; color: main.text; anchors.verticalCenter: parent.verticalCenter; font { family: main.font; pixelSize: 12; weight: 600 } }
        }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.dnd = !root.nf.dnd }
    }
    Rectangle {
        id: clear
        anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 12 }
        height: 30; width: clearText.implicitWidth + 22; radius: 15
        opacity: root.items.length > 0 ? 1 : 0.4
        color: cm.containsMouse ? main.card : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
        Text { id: clearText; anchors.centerIn: parent; text: "Clear"; color: main.text; font { family: main.font; pixelSize: 12; weight: 600 } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.clearAll() }
    }

    ListView {
        id: list
        x: 12; y: 56; width: parent.width - 24; height: Math.max(110, Math.min(380, contentHeight))
        model: root.items; clip: true; spacing: 8
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: main.ms(260) } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: main.ms(180) } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: main.ms(300); easing.type: Easing.OutCubic } }
        delegate: Rectangle {
            id: row
            required property var modelData
            width: list.width; height: rc.implicitHeight + 22; radius: 16
            color: Qt.rgba(main.card.r, main.card.g, main.card.b, 0.7); border.width: 1
            border.color: modelData.urgency === NotificationUrgency.Critical ? main.red : main.line
            Row {
                id: rc; x: 12; y: 11; spacing: 10; width: parent.width - 24
                Rectangle {
                    width: 32; height: 32; radius: 10; color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.16); clip: true
                    Image {
                        anchors.fill: parent; anchors.margins: row.modelData.image !== "" ? 0 : 6
                        source: row.modelData.image !== "" ? row.modelData.image : (row.modelData.appIcon !== "" ? Quickshell.iconPath(row.modelData.appIcon, "dialog-information") : "")
                        fillMode: Image.PreserveAspectCrop; asynchronous: true
                    }
                    Text { anchors.centerIn: parent; visible: row.modelData.image === "" && row.modelData.appIcon === ""; text: String.fromCodePoint(0xF009A); color: main.accent
                        font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 16 } }
                }
                Column {
                    width: parent.width - 42 - 26; spacing: 1
                    Text { width: parent.width; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText; text: String(row.modelData.summary || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(); color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
                    Text { visible: text !== ""; width: parent.width; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; textFormat: Text.PlainText
                        text: String(row.modelData.body || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim(); color: main.muted; font { family: main.font; pixelSize: 11 } }
                    Text { text: row.modelData.appName; color: main.muted; opacity: 0.7; font { family: main.font; pixelSize: 10; weight: 600 } }
                }
                Text {
                    text: "×"; color: xm.containsMouse ? main.red : main.muted; width: 20
                    font { pixelSize: 20 }
                    MouseArea { id: xm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.nf) root.nf.removeHistory(row.modelData) }
                }
            }
        }
        Text {
            anchors.centerIn: parent; visible: root.items.length === 0
            text: root.nf && root.nf.dnd ? "Quiet mode is on" : "You're all caught up"
            color: main.muted; font { family: main.font; pixelSize: 13 }
        }
    }
}
