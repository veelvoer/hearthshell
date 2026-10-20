import QtQuick

// One option of a widget, drawn from its entry in WidgetDefs: a switch, a slider, a few choices, a text field or a file.
Item {
    id: root
    required property var opt
    property var value
    signal changed(var v)
    signal pickFile()
    signal typingChanged(bool typing)
    readonly property string kind: opt.kind
    readonly property var choices: opt.choices || []
    readonly property int current: {
        for (let i = 0; i < choices.length; i++) if (String(choices[i][0]) === String(value)) return i;
        return 0;
    }
    width: parent ? parent.width : 300
    height: kind === "toggle" ? 40 : kind === "slider" ? 56 : 70

    Rectangle { visible: root.y > 0.5; anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 } height: 1; color: Qt.rgba(main.text.r, main.text.g, main.text.b, 0.06) }
    Text {
        x: 2; y: root.kind === "toggle" ? (root.height - height) / 2 : 6
        text: root.opt.label; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 }
    }

    HToggle {
        visible: root.kind === "toggle"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        checked: !!root.value; onToggled: v => root.changed(v)
    }

    Text {
        visible: root.kind === "slider"; anchors { right: parent.right; top: parent.top; topMargin: 6 }
        text: Number(root.value).toFixed(root.opt.decimals || 0) + (root.opt.unit || ""); color: main.muted; font { family: main.font; pixelSize: 12 }
    }
    HSlider {
        visible: root.kind === "slider"; x: 2; y: 28; width: parent.width - 4
        from: root.opt.min !== undefined ? root.opt.min : 0; to: root.opt.max !== undefined ? root.opt.max : 1; value: Number(root.value) || 0
        onMoved: v => { const st = root.opt.step || 1; root.changed(Math.max(root.opt.min, Math.min(root.opt.max, Math.round(v / st) * st))); }
    }

    HSegment {
        visible: root.kind === "choice"; x: 0; y: 30
        options: root.choices.map(c => c[1]); segWidth: Math.floor((root.width - 6) / Math.max(1, root.choices.length))
        current: root.current; onPicked: i => root.changed(root.choices[i][0])
    }

    HInput {
        id: field
        visible: root.kind === "text"; x: 0; y: 30; width: parent.width; height: 34
        placeholder: root.opt.hint || ""
        Component.onCompleted: text = String(root.value === undefined ? "" : root.value)
        onEdited: v => root.changed(v)
        onTypingChanged: root.typingChanged(typing)
    }

    Row {
        visible: root.kind === "file"; x: 0; y: 30; spacing: 8
        HButton { label: String(root.value || "") === "" ? "Choose…" : "Change…"; primary: true; onClicked: root.pickFile() }
        HButton { visible: String(root.value || "") !== ""; label: "Remove"; onClicked: root.changed("") }
        Text {
            anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, root.width - 190); elide: Text.ElideMiddle
            visible: String(root.value || "") !== ""; text: String(root.value || "").split("/").pop(); color: main.muted; font { family: main.font; pixelSize: 12 }
        }
    }
}
