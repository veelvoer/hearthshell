// qmllint disable
import Quickshell.Services.Pipewire
import QtQuick

// Sound: the output volume, which speakers or headphones are used, the microphone, and each app's own volume.
Item {
    id: root
    property bool active: false
    property bool settled: false
    property var shell: null
    readonly property bool typing: false
    readonly property var all: Pipewire.nodes.values
    function ordered(list, current) {
        const v = list.slice();
        v.sort((a, b) => (b === current) - (a === current) || nameOf(a).localeCompare(nameOf(b)));
        return v;
    }
    readonly property var outs: ordered(all.filter(n => n.isSink && !n.isStream && !!n.audio), sink)
    readonly property var ins: ordered(all.filter(n => !n.isSink && !n.isStream && !!n.audio && !(n.name || "").endsWith(".monitor")), source)
    readonly property var apps: all.filter(n => n.isSink && n.isStream && !!n.audio).slice(0, 4)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: !!sink && sink.ready && !!sink.audio
    readonly property real wantedHeight: 62 + col.implicitHeight + 16
    PwObjectTracker { objects: root.all }

    function nameOf(n) { return n ? (n.nickname || n.description || n.name || "Device") : ""; }
    function appName(n) { const p = n.properties || {}; return p["application.name"] || p["media.name"] || n.nickname || n.name || "App"; }

    Text { x: 54; y: 15; text: "Sound"; color: main.text; font { family: main.serif; pixelSize: 18 } }

    component Heading: Text { color: main.muted; font { family: main.font; pixelSize: 12; weight: 600 } }
    component DeviceRow: Rectangle {
        id: dr
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal clicked()
        width: parent.width; height: 46; radius: 23
        color: on ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.92) : (dm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.12) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07))
        Behavior on color { ColorAnimation { duration: main.ms(180) } }
        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: dr.glyph; color: dr.on ? main.bg : main.text; font { family: "JetBrainsMono Nerd Font Propo"; pixelSize: 18 } }
        Text { x: 48; width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: dr.label
            color: dr.on ? main.bg : main.text; font { family: main.font; pixelSize: 13; weight: dr.on ? 700 : 500 } }
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dr.clicked() }
    }

    Flickable {
        id: scroller
        x: 12; y: 58; width: parent.width - 24; height: Math.max(0, parent.height - 58 - 12)
        contentWidth: width; contentHeight: col.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: scroller.width; spacing: 8
        PillSlider {
            width: parent.width
            glyph: root.ready && root.sink.audio.muted ? String.fromCodePoint(0xF0581) : String.fromCodePoint(0xF057E)
            from: 0; to: 1; value: root.ready ? root.sink.audio.volume : 0
            valueText: !root.ready ? "" : root.sink.audio.muted ? "Muted" : Math.round(root.sink.audio.volume * 100) + "%"
            onMoved: v => { if (root.ready) { root.sink.audio.volume = v; root.sink.audio.muted = false; } }
        }
        Heading { text: "Output"; leftPadding: 6; topPadding: 4 }
        Repeater {
            model: root.outs
            delegate: DeviceRow {
                required property var modelData
                glyph: String.fromCodePoint(0xF04C3); label: root.nameOf(modelData); on: modelData === root.sink
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
        Heading { visible: root.ins.length > 0; text: "Input"; leftPadding: 6; topPadding: 4 }
        Repeater {
            model: root.ins
            delegate: DeviceRow {
                required property var modelData
                glyph: String.fromCodePoint(0xF036C); label: root.nameOf(modelData); on: modelData === root.source
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
        Heading { visible: root.apps.length > 0; text: "Apps"; leftPadding: 6; topPadding: 4 }
        Repeater {
            model: root.apps
            delegate: Item {
                required property var modelData
                width: col.width; height: 44
                Text { x: 6; width: 110; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: root.appName(modelData); color: main.text
                    font { family: main.font; pixelSize: 12; weight: 600 } }
                HSlider {
                    x: 124; width: parent.width - 124 - 46; anchors.verticalCenter: parent.verticalCenter
                    from: 0; to: 1; value: modelData.audio.volume
                    onMoved: v => { modelData.audio.volume = v; }
                }
                Text { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } text: Math.round(modelData.audio.volume * 100) + "%"; color: main.muted
                    font { family: main.font; pixelSize: 11; weight: 600 } }
            }
        }
        }
    }
}
