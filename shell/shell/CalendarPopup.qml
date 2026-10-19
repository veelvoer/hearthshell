// qmllint disable
import Quickshell
import QtQuick

// Calendar card: the time big, today's date, and a month you can page through.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    signal requestClose()
    readonly property real wantedHeight: 198 + grid.rows * 40 + 16

    SystemClock { id: clock; precision: SystemClock.Seconds }
    property int shift: 0                          // months away from the current one
    onActiveChanged: if (active) shift = 0
    readonly property date today: clock.date
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + shift, 1)
    readonly property int firstDow: cfg.weekMonday ? 1 : 0      // 0 = Sunday
    readonly property int lead: (shown.getDay() - firstDow + 7) % 7
    readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

    Text {
        x: 54; y: 15; text: "Calendar"; color: main.text
        font { family: main.serif; pixelSize: 18 }
    }
    Column {
        x: 18; y: 58; width: parent.width - 36; spacing: 0
        Text {
            text: Qt.formatDateTime(root.today, (cfg.clock24 ? "hh:mm" : "h:mm") + (cfg.clockSeconds ? ":ss" : "") + (cfg.clock24 ? "" : " AP"))
            color: main.text; font { family: main.font; pixelSize: 40; weight: 300 }
        }
        Text {
            text: Qt.formatDate(root.today, "dddd d MMMM yyyy")
            color: main.accent; font { family: main.font; pixelSize: 14; weight: 600 }
        }
    }
    // month header with paging
    Item {
        id: head
        x: 14; y: 62 + 74; width: parent.width - 28; height: 36
        Text {
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            text: Qt.formatDate(root.shown, "MMMM yyyy"); color: main.text
            font { family: main.font; pixelSize: 14; weight: 700 }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4
            Repeater {
                model: [{ "t": "‹", "d": -1 }, { "t": "●", "d": 0 }, { "t": "›", "d": 1 }]
                delegate: Rectangle {
                    required property var modelData
                    width: 30; height: 30; radius: 15
                    color: bm.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.25) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
                    Behavior on color { ColorAnimation { duration: main.ms(140) } }
                    Text { anchors.centerIn: parent; text: modelData.t; color: main.text; font { pixelSize: modelData.d === 0 ? 8 : 20; weight: 600 } }
                    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.shift = modelData.d === 0 ? 0 : root.shift + modelData.d }
                }
            }
        }
    }
    Row {
        id: dow
        x: 14; y: head.y + 40; width: parent.width - 28
        Repeater {
            model: 7
            Text {
                required property int index
                width: dow.width / 7; horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.ShortFormat).slice(0, 2)
                color: main.muted; font { family: main.font; pixelSize: 11; weight: 600 }
            }
        }
    }
    Grid {
        id: grid
        x: 14; y: dow.y + 22; width: parent.width - 28; columns: 7
        readonly property int rows: Math.ceil((root.lead + root.days) / 7)
        Repeater {
            model: grid.rows * 7
            delegate: Item {
                required property int index
                readonly property int day: index - root.lead + 1
                readonly property bool inMonth: day >= 1 && day <= root.days
                readonly property bool isToday: inMonth && root.shift === 0 && day === root.today.getDate()
                width: grid.width / 7; height: 40
                Rectangle {
                    anchors.centerIn: parent; width: 34; height: 34; radius: 17
                    color: isToday ? main.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: main.ms(200) } }
                    Text {
                        anchors.centerIn: parent; visible: inMonth; text: day
                        color: isToday ? main.bg : main.text
                        font { family: main.font; pixelSize: 13; weight: isToday ? 700 : 500 }
                    }
                }
            }
        }
    }
}
