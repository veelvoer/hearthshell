// qmllint disable
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// The pop-ups for incoming notifications: a small stack under the bar that glides in, with a progress hairline.
PanelWindow {
    id: win
    required property var shell
    required property var notifier
    readonly property real gapTop: shell.barTopMargin + shell.barHeight + 8
    readonly property bool bottom: shell.cfg.barPos === "bottom"

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: notifier.toasts.length > 0 || stack.height > 1
    mask: Region { item: stack }

    Column {
        id: stack
        width: 380
        x: (parent.width - width) / 2
        y: win.bottom ? parent.height - height - win.gapTop : win.gapTop
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: main.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }

        Repeater {
            model: win.notifier.toasts
            delegate: Item {
                id: toast
                required property var modelData
                readonly property var n: modelData
                readonly property bool critical: n.urgency === NotificationUrgency.Critical
                width: stack.width
                height: card.height
                property real k: 0
                Component.onCompleted: { k = 1; life.start(); }
                Behavior on k { NumberAnimation { duration: main.ms(520); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.25, 0.64, 1, 1, 1] } }
                opacity: Math.min(1, k * 1.6)

                // time on screen: the app's own timeout, otherwise 6 s (critical ones stay until dismissed)
                Timer {
                    id: life
                    interval: toast.critical ? 600000 : (toast.n.expireTimeout > 0 ? toast.n.expireTimeout * 1000 : 6000)
                    running: false
                    onTriggered: win.notifier.hide(toast.n)
                }
                // hovering holds the pop-up
                property bool held: hover.hovered
                onHeldChanged: if (held) life.stop(); else life.restart();

                Rectangle {
                    id: card
                    width: parent.width
                    height: col.implicitHeight + 24
                    radius: Math.min(22, shell.cfg.barRadius + 7)
                    color: Qt.alpha(main.bg, main.menuAlpha)
                    border.width: 1; border.color: toast.critical ? main.red : main.border
                    transform: [ Translate { y: (1 - toast.k) * (win.bottom ? 24 : -24) }, Scale { origin.x: card.width / 2; origin.y: win.bottom ? card.height : 0; xScale: 0.92 + 0.08 * toast.k; yScale: 0.92 + 0.08 * toast.k } ]
                    HoverHandler { id: hover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { win.notifier.hide(toast.n); toast.n.dismiss(); }
                    }
                    Row {
                        x: 14; y: 12; spacing: 12; width: parent.width - 28
                        Rectangle {
                            width: 38; height: 38; radius: 12; color: Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.16)
                            clip: true
                            Image {
                                anchors.fill: parent; anchors.margins: toast.n.image !== "" ? 0 : 7
                                source: toast.n.image !== "" ? toast.n.image : (toast.n.appIcon !== "" ? Quickshell.iconPath(toast.n.appIcon, "dialog-information") : "")
                                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                            }
                            Text { anchors.centerIn: parent; visible: toast.n.image === "" && toast.n.appIcon === ""; text: String.fromCodePoint(0xF009A); color: main.accent
                                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
                        }
                        Column {
                            id: col
                            width: parent.width - 50; spacing: 2
                            Text {
                                width: parent.width; elide: Text.ElideRight; text: toast.n.summary
                                color: main.text; font { family: main.font; pixelSize: 14; weight: 600 }
                            }
                            Text {
                                visible: text !== ""; width: parent.width; maximumLineCount: 3; wrapMode: Text.Wrap; elide: Text.ElideRight
                                text: toast.n.body; color: main.muted; font { family: main.font; pixelSize: 12 }
                            }
                            Text {
                                text: toast.n.appName; color: main.muted; opacity: 0.7
                                font { family: main.font; pixelSize: 10; weight: 600; capitalization: Font.AllUppercase; letterSpacing: 0.6 }
                            }
                            Flow {
                                visible: toast.n.actions.length > 0; width: parent.width; spacing: 6
                                Repeater {
                                    model: toast.n.actions
                                    delegate: Rectangle {
                                        required property var modelData
                                        height: 26; width: lbl.implicitWidth + 22; radius: 13
                                        color: am.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.3) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.08)
                                        Text { id: lbl; anchors.centerIn: parent; text: modelData.text; color: main.text; font { family: main.font; pixelSize: 11; weight: 600 } }
                                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onClicked: { modelData.invoke(); win.notifier.hide(toast.n); } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
