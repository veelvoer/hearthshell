// qmllint disable
import QtQuick

// Label + description, with a value read-out and a slider.
HRow {
    id: row
    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 0.01
    property int decimals: 2
    property string unit: ""
    signal moved(real value)

    Row {
        spacing: 12
        Text {
            width: 52; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
            text: row.value.toFixed(row.decimals) + row.unit; color: main.muted
            font { family: main.font; pixelSize: 12; weight: 600 }
        }
        HSlider {
            width: 190; from: row.from; to: row.to; value: row.value
            onMoved: v => row.moved(Math.max(row.from, Math.min(row.to, Math.round(v / row.step) * row.step)))
        }
    }
}
