// qmllint disable
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects

// Cover art blurred into the background, title, artist, transport buttons and a progress bar.
Rectangle {
    id: card
    property var p: null
    property bool tall: false
    readonly property bool hasArt: art.status === Image.Ready
    readonly property color fg: hasArt ? "#ffffff" : main.text
    readonly property color fg2: hasArt ? "#d8d8d8" : main.muted
    height: tall ? 200 : 152; radius: 26
    color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
    function cp(n) { return String.fromCodePoint(n); }
    Item {
        id: maskItem
        visible: false; layer.enabled: true
        width: card.width; height: card.height
        Rectangle { anchors.fill: parent; radius: card.radius; color: "black" }
    }
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: maskItem; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Image {
            id: art
            anchors.fill: parent
            source: card.p && card.p.trackArtUrl ? card.p.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(240, 240)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 48; blur: 1.0; saturation: 0.15 }
        }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, card.hasArt ? 0.45 : 0) }
    }
    Rectangle {
        id: cover
        visible: card.tall && card.hasArt
        x: 20; y: 20; width: 96; height: 96; radius: 18; clip: true; color: "transparent"
        Image { anchors.fill: parent; source: art.source; fillMode: Image.PreserveAspectCrop; smooth: true; sourceSize: Qt.size(192, 192) }
    }
    Column {
        x: card.tall && card.hasArt ? 130 : 20; y: card.tall ? 30 : 14; width: parent.width - x - 20 - 30; spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: card.p ? (card.p.trackTitle || "Nothing playing") : "Nothing playing"; color: card.fg
            font { family: main.font; pixelSize: card.tall ? 18 : 16; weight: 700 } }
        Text { width: parent.width; elide: Text.ElideRight; text: card.p ? (card.p.trackArtist || "") : ""; color: card.fg2
            font { family: main.font; pixelSize: 13 } }
        Text { width: parent.width; elide: Text.ElideRight; visible: card.tall && !!card.p; text: card.p ? (card.p.identity || "") : ""; color: card.fg2; opacity: 0.7
            font { family: main.font; pixelSize: 11 } }
    }
    EqBars { anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 18 } size: 18; running: !!card.p && card.p.isPlaying; tint: card.hasArt ? "#ffffff" : main.accent }
    Row {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: card.tall ? 44 : 40 }
        spacing: 24
        Text { anchors.verticalCenter: parent.verticalCenter; text: card.cp(0xF04AE); opacity: card.p && card.p.canGoPrevious ? 1 : 0.4
            color: card.fg; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: if (card.p && card.p.canGoPrevious) card.p.previous() } }
        Rectangle {
            width: 46; height: 46; radius: 23; color: card.hasArt ? "#f2f2f2" : main.accent
            scale: pp.pressed ? 0.93 : 1
            Behavior on scale { NumberAnimation { duration: main.ms(150); easing.type: Easing.OutBack } }
            Text { anchors.centerIn: parent; text: card.cp(card.p && card.p.isPlaying ? 0xF03E4 : 0xF040A); color: "#101010"
                font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 } }
            MouseArea { id: pp; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (card.p && card.p.canTogglePlaying) card.p.togglePlaying() }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: card.cp(0xF04AD); opacity: card.p && card.p.canGoNext ? 1 : 0.4
            color: card.fg; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 22 }
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: if (card.p && card.p.canGoNext) card.p.next() } }
    }
    // progress: click or drag to seek
    Item {
        x: 20; y: parent.height - 24; width: parent.width - 40; height: 16
        visible: !!card.p && card.p.lengthSupported && card.p.length > 0
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 5; radius: 3; color: Qt.rgba(1, 1, 1, 0.25)
            Rectangle {
                height: parent.height; radius: 3; color: card.hasArt ? "#ffffff" : main.accent
                width: card.p && card.p.length > 0 ? parent.width * Math.max(0, Math.min(1, card.p.position / card.p.length)) : 0
                Behavior on width { enabled: !seek.pressed; NumberAnimation { duration: main.ms(900); easing.type: Easing.Linear } }
            }
        }
        MouseArea {
            id: seek; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            function to(mx) { if (card.p && card.p.canSeek && card.p.positionSupported) card.p.position = Math.max(0, Math.min(1, mx / width)) * card.p.length; }
            onPressed: mouse => to(mouse.x)
            onPositionChanged: mouse => { if (pressed) to(mouse.x) }
        }
    }
}
