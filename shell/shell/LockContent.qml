// qmllint disable
import Quickshell
import QtQuick
import QtQuick.Effects

// One lockscreen surface: frozen blurred screenshot + the morphing clock + password field.
// shell.morph: 0 = lockscreen position, 1 = exactly on top of the bar clock.
Item {
    id: root
    required property var shell
    required property string shotPath
    property string status: ""
    signal submit(string password)

    function focusInput() { input.forceActiveFocus(); }
    function clear() { input.text = ""; }
    function shake() { shakeAnim.restart(); }

    readonly property real p: shell.morph
    readonly property real f: shell.lockFontPx + (shell.barFontPx - shell.lockFontPx) * p
    readonly property real barX: shell.barClockX >= 0 ? shell.barClockX : cx
    readonly property real barY: shell.cfg.barPos === "bottom" ? height - shell.barCenterY : shell.barCenterY
    readonly property real cx: width / 2
    readonly property real cy: height * 0.40
    readonly property real gap: shell.stackGap * f / shell.lockFontPx
    function lerp(a, b) { return a + (b - a) * p; }

    // ---- frozen desktop, blurred --------------------------------------
    Image {
        id: shot
        anchors.fill: parent
        source: root.shotPath
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: false
        layer.enabled: false
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        blurEnabled: true
        blur: shell.blurAmt * shell.cfg.lockBlur
        blurMax: 56
        brightness: -0.12 * shell.blurAmt * shell.cfg.lockBlur
        saturation: -0.1 * shell.blurAmt * shell.cfg.lockBlur
    }

    // ---- bar-size measuring (exact end state) -------------------------
    readonly property string fam: shell.clockFont
    Text { id: mCol; visible: false; text: ":"; font.family: root.fam; font.pixelSize: root.f; font.weight: 600 }

    readonly property real hW: hours.width
    readonly property real mW: minutes.width
    readonly property real cW: mCol.width
    readonly property real total: hW + cW + mW
    readonly property real q: Math.max(0, Math.min(1, (p - 0.45) / 0.55))   // bold-green -> bar style

    Text {
        id: hours
        text: Qt.formatDateTime(shell.clock.date, "HH")
        color: shell.main.text
        font.family: root.fam
        font.pixelSize: root.f
        font.weight: 600
        renderType: Text.NativeRendering
        x: root.lerp(root.cx, root.barX - root.total / 2 + root.hW / 2) - width / 2
        y: root.lerp(root.cy - root.gap, root.barY) - height / 2
    }

    // minutes, bar style (plain text colour)
    Text {
        id: minutes
        text: Qt.formatDateTime(shell.clock.date, "mm")
        color: shell.main.text
        font.family: root.fam
        font.pixelSize: root.f
        font.weight: 600
        renderType: Text.NativeRendering
        opacity: root.q
        x: root.lerp(root.cx, root.barX - root.total / 2 + root.hW + root.cW + root.mW / 2) - width / 2
        y: root.lerp(root.cy + root.gap, root.barY) - height / 2
    }
    // minutes, lockscreen style (bold green), same centre
    Text {
        text: minutes.text
        color: shell.main.wsa
        font.family: root.fam
        font.pixelSize: root.f
        font.bold: true
        renderType: Text.NativeRendering
        opacity: 1 - root.q
        x: minutes.x + (minutes.width - width) / 2
        y: minutes.y
    }

    Text {
        text: ":"
        color: shell.main.text
        font.family: root.fam
        font.pixelSize: root.f
        font.weight: 600
        renderType: Text.NativeRendering
        opacity: Math.max(0, Math.min(1, (root.p - 0.55) / 0.45))
        x: root.cx - root.total / 2 + root.hW + root.cW / 2 - width / 2
        y: root.lerp(root.cy, root.barY) - height / 2
    }

    // ---- date above the clock ------------------------------------------
    Text {
        visible: shell.cfg.lockDate
        opacity: shell.uiOpacity
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.cy - root.gap - root.f * 0.8
        text: Qt.formatDateTime(shell.clock.date, "dddd d MMMM")
        color: shell.main.muted
        font.family: root.fam
        font.pixelSize: Math.max(14, root.f * 0.2)
        font.weight: 500
        renderType: Text.NativeRendering
    }

    // ---- password field -----------------------------------------------
    Item {
        id: ui
        opacity: shell.uiOpacity
        width: 260; height: 70
        x: root.cx - width / 2
        y: root.cy + shell.lockFontPx * 1.35

        Rectangle {
            id: pill
            width: 240; height: 44
            radius: 22
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(0.176, 0.208, 0.231, 0.55)
            border.width: 1
            border.color: input.activeFocus ? shell.main.wsa : shell.main.border

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: "Password"
                color: shell.main.text
                opacity: 0.45
                font.family: root.fam
                font.pixelSize: 14
            }
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: shell.main.text
                font.family: root.fam
                font.pixelSize: 16
                enabled: !shell.authBusy
                focus: true
                onAccepted: if (text.length > 0) root.submit(text)
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -14; duration: 55 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 14; duration: 90 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: -8; duration: 80 }
                NumberAnimation { target: pill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 70 }
            }
        }

        Text {
            anchors.top: pill.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.status
            color: shell.main.wsti
            font.family: root.fam
            font.pixelSize: 12
        }
    }

    // keep the field focused
    MouseArea { anchors.fill: parent; onPressed: root.focusInput() }
    Component.onCompleted: focusInput()
}
