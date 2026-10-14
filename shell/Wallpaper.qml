// qmllint disable
import QtQuick
import QtQuick.Effects

// Crossfading wallpaper surface.
Item {
    id: root
    property string source: ""
    property real dim: 0
    property real blur: 0
    property bool fit: false
    property bool primed: false

    // shown until (or instead of) a wallpaper image: a quiet gradient in the theme colours
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(main.bg, 1.15) }
            GradientStop { position: 1; color: Qt.darker(main.bg, 1.9) }
        }
    }
    Item {
        id: stack
        anchors.fill: parent
        layer.enabled: root.blur > 0.01
        layer.effect: MultiEffect { blurEnabled: true; blur: root.blur; blurMax: 48; autoPaddingEnabled: false }
    Image {
        id: prev
        anchors.fill: parent
        fillMode: root.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
    }
    Image {
        id: cur
        anchors.fill: parent
        fillMode: root.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        opacity: 0
        onStatusChanged: if (status === Image.Ready) {
            fade.restart();
        }
    }
    }
    NumberAnimation {
        id: fade
        target: cur; property: "opacity"; from: 0; to: 1
        duration: root.primed ? main.ms(900) : 1
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        onFinished: { root.primed = true; prev.source = cur.source; }
    }
    onSourceChanged: {
        if (source === "" || source === cur.source) return;
        fade.stop();
        if (cur.opacity > 0.5) prev.source = cur.source;   // keep what is visible underneath
        cur.opacity = 0;
        cur.source = source;
    }
    Component.onCompleted: if (source !== "") cur.source = source

    Rectangle { anchors.fill: parent; color: "black"; opacity: root.dim; Behavior on opacity { NumberAnimation { duration: main.ms(250) } } }
}
