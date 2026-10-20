// qmllint disable
import Quickshell
import QtQuick

Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    signal requestClose()
    readonly property real rowH: 32
    readonly property real wantedHeight: 12 + 34 + 26 + rowH * 6 + 14

    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int shift: 0
    onActiveChanged: if (active) shift = 0
    readonly property date today: clock.date
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + shift, 1)
    readonly property int firstDow: cfg.weekMonday ? 1 : 0
    readonly property int lead: (shown.getDay() - firstDow + 7) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    readonly property int prevDays: new Date(shown.getFullYear(), shown.getMonth(), 0).getDate()

    Item {
        id: head
        x: 14; y: 12; width: parent.width - 28; height: 34
        Repeater {
            model: [{ "t": "‹", "d": -1 }, { "t": "›", "d": 1 }]
            delegate: Rectangle {
                required property var modelData
                width: 26; height: 26; radius: 13
                anchors.verticalCenter: parent.verticalCenter
                x: modelData.d < 0 ? 0 : parent.width - width
                color: bm.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.25) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.10)
                Behavior on color { ColorAnimation { duration: main.ms(140) } }
                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: modelData.t; color: main.text; font { family: main.font; pixelSize: 16; weight: 600 } }
                MouseArea {
                    id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.shift += modelData.d
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: Qt.formatDate(root.shown, "MMMM yyyy"); color: main.text
            font { family: main.font; pixelSize: 13; weight: 700 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.shift = 0 }
        }
    }
    Row {
        id: dow
        x: 14; y: head.y + head.height + 4; width: parent.width - 28
        Repeater {
            model: 7
            Text {
                required property int index
                width: dow.width / 7; horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.ShortFormat).slice(0, 1).toUpperCase()
                color: main.muted; font { family: main.font; pixelSize: 10; weight: 700 }
            }
        }
    }
    Grid {
        id: grid
        x: 14; y: dow.y + 22; width: parent.width - 28; columns: 7
        Repeater {
            model: 42
            delegate: Item {
                required property int index
                readonly property int day: index - root.lead + 1
                readonly property bool inMonth: day >= 1 && day <= root.days
                readonly property int shownDay: inMonth ? day : (day < 1 ? root.prevDays + day : day - root.days)
                readonly property bool isToday: inMonth && root.shift === 0 && day === root.today.getDate()
                width: grid.width / 7; height: root.rowH
                Rectangle {
                    anchors.centerIn: parent; width: 26; height: 26; radius: 13
                    color: isToday ? main.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: main.ms(200) } }
                    Text {
                        anchors.centerIn: parent; text: shownDay
                        color: isToday ? main.onAccent : (inMonth ? main.text : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.25))
                        font { family: main.font; pixelSize: 12; weight: isToday ? 700 : 500 }
                    }
                }
            }
        }
    }
}
