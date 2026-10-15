// qmllint disable
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

BarButton {
    id: root

    toneName: "yellow"
    property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink && sink.ready
    readonly property bool muted: ready && sink.audio.muted
    readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

    readonly property string icon: {
        if (!ready) return String.fromCodePoint(0xF0581)
        if (muted) return "󰸈"
        if (vol === 0) return String.fromCodePoint(0xF0581)
        if (vol < 34) return String.fromCodePoint(0xF057F)
        if (vol < 67) return String.fromCodePoint(0xF0580)
        return String.fromCodePoint(0xF057E)
    }

    onClicked: if (ready) sink.audio.muted = !sink.audio.muted
    onScrolled: dir => { if (ready) sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + dir * 0.05)); }

    Text {
        text: root.icon
        color: root.iconColor
        font {
            family: "JetBrainsMono Nerd Font Propo"
            pixelSize: main.barPx
        }
    }

    HoverLabel {
        host: root
        shown: cfg.labelVolume
        text: {
            if (!root.ready) return "-"
            if (root.muted) return "Muted"
            return root.vol + "%"
        }
        color: main.text
        font.family: main.font
        font.pixelSize: main.barPx
        font.weight: 500
    }

    PwObjectTracker {
        objects: [root.sink]
    }
}
