// qmllint disable
import QtQuick

// One piece of content inside the dynamic island. It waits for the island's shape to start morphing,
// then fades in with a small spring; when it is replaced it fades out first (same rhythm as the lock-screen clock).
Item {
    id: pane
    property bool on: false
    property real inScale: 0.94
    opacity: 0
    visible: opacity > 0.01

    states: State { name: "on"; when: pane.on; PropertyChanges { target: pane; opacity: 1 } }
    transitions: [
        Transition {
            to: "on"
            SequentialAnimation {
                PropertyAction { target: pane; property: "scale"; value: pane.inScale }
                PauseAnimation { duration: main.ms(150) }
                ParallelAnimation {
                    NumberAnimation { target: pane; property: "opacity"; duration: main.ms(230); easing.type: Easing.OutCubic }
                    NumberAnimation { target: pane; property: "scale"; to: 1; duration: main.ms(420)
                        easing.type: Easing.BezierSpline; easing.bezierCurve: main.popCurve }
                }
            }
        },
        Transition {
            from: "on"
            NumberAnimation { target: pane; property: "opacity"; duration: main.ms(110) }
        }
    ]
}
