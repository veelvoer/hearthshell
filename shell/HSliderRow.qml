// qmllint disable
import QtQuick

// Label on the left, value on the right, slider underneath.
HRow {
    id: row
    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 0.01
    property int decimals: 2
    property string unit: ""
    signal moved(real value)
    height: 64
    labelCenter: 22

    Text {
        text: row.value.toFixed(row.decimals) + row.unit; color: main.muted
        font { family: main.font; pixelSize: 12; weight: 500 }
    }
    HSlider {
        parent: row
        x: 2; y: 33; width: row.width - 4
        from: row.from; to: row.to; value: row.value
        onMoved: v => row.moved(Math.max(row.from, Math.min(row.to, Math.round(v / row.step) * row.step)))
    }
}
