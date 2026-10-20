// qmllint disale
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

RowLayout {
    spacing: 6
    property var bar: null
    property string zone: ""
    property bool flat: bar ? bar.style === "minimal" : false   // minimal bar: only the active workspace gets a fill

    readonly property string wsStyle: cfg.wsStyle
    readonly property bool animated: ["bars", "scroll", "stretch"].indexOf(cfg.wsStyle) >= 0

    WorkspaceStyle {
        visible: parent.animated
        kind: cfg.wsStyle
        Layout.preferredWidth: implicitWidth; Layout.preferredHeight: implicitHeight
        Layout.maximumWidth: parent.animated ? implicitWidth : 0
    }

    Repeater {
        model: parent.animated ? 0 : cfg.wsCount

        Rectangle {
            id: wsButton
            required property int index

            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
            readonly property bool dots: cfg.wsStyle === "dots"
            readonly property bool plain: cfg.wsStyle === "numbers"

            visible: !cfg.wsOccupiedOnly || isActive || !!ws
            implicitWidth: dots ? (isActive ? 22 : 8) : label.implicitWidth + 14
            implicitHeight: dots ? 8 : main.barPx + 9
            Behavior on implicitWidth { NumberAnimation { duration: main.ms(260); easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1] } }
            radius: dots ? 4 : 6

            color: plain ? "transparent"
                 : isActive ? main.wsa : (flat && !dots ? "transparent" : (ws ? main.wso : main.wsi))

            Behavior on color { ColorAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }

            // the active dot glows in the accent colour
            layer.enabled: dots && isActive
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: main.wsa; shadowBlur: 0.9; shadowOpacity: 0.85
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }

            scale: press.pressed ? 0.92 : (press.containsMouse ? 1.08 : 1)
            Behavior on scale { NumberAnimation { duration: main.ms(200); easing.type: Easing.OutBack } }

            Text {
                id: label
                visible: !wsButton.dots
                anchors.centerIn: parent
                text: wsButton.index + 1
                color: wsButton.plain ? (wsButton.isActive ? main.wsa : (wsButton.ws ? main.text : main.muted))
                     : wsButton.isActive ? main.wst : (wsButton.ws ? main.wsti : main.wsti)
                Behavior on color { ColorAnimation { duration: main.ms(240); easing.type: Easing.OutCubic } }

                font {
                    family: main.font
                    pixelSize: main.barPx
                    weight: 650
                }
            }

            // underline for the plain-number style
            Rectangle {
                visible: wsButton.plain
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                height: 2; radius: 1; color: main.wsa
                width: wsButton.isActive ? parent.width - 6 : 0
                Behavior on width { NumberAnimation { duration: main.ms(220); easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: press
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (parent.index + 1) + "})")
            }
        }
    }
}
