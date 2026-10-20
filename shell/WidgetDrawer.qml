import QtQuick

// The Customize panel of the desktop editor: everything about the selected widget, in three groups that open one at a time.
Rectangle {
    id: root
    required property var editor
    readonly property var spec: editor.selectedSpec
    readonly property var defs: editor.shell.widgetDefs
    readonly property var def: spec ? defs.types[spec.type] : null
    property string section: "content"
    width: 340
    radius: 26; color: Qt.rgba(main.bg.r, main.bg.g, main.bg.b, 0.95); border.width: 1; border.color: main.border
    onSpecChanged: if (spec && root.def && (!root.def.options || root.def.options.length === 0) && section === "content") section = "look"

    Text { x: 22; y: 20; text: root.def ? root.def.label : ""; color: main.text; font { family: main.font; pixelSize: 16; weight: 700 } }
    Rectangle {
        width: 28; height: 28; radius: 14; x: parent.width - width - 16; y: 16
        color: cm.containsMouse ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: "×"; color: main.text; font { pixelSize: 17; weight: 600 } }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editor.customizing = false }
    }

    Flickable {
        id: fl
        x: 0; y: 62; width: parent.width; height: parent.height - 62 - 10
        contentWidth: width; contentHeight: col.height + 8
        clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
        Column {
            id: col
            x: 14; width: parent.width - 28; spacing: 8

            DrawerSection {
                title: "Content"; visible: !!root.def && !!root.def.options && root.def.options.length > 0
                expanded: root.section === "content"; onToggled: root.section = expanded ? "" : "content"
                Column {
                    width: parent.width
                    Repeater {
                        model: root.def && root.def.options ? root.def.options : []
                        delegate: OptionRow {
                            required property var modelData
                            opt: modelData
                            value: root.spec ? root.defs.val(root.spec, modelData.key) : undefined
                            onChanged: v => root.editor.setOption(root.spec.id, modelData.key, v)
                            onPickFile: root.editor.pickImage(root.spec.id, modelData.key)
                            onTypingChanged: typing => root.editor.typing = typing
                        }
                    }
                }
            }
            DrawerSection {
                title: "Look"
                expanded: root.section === "look"; onToggled: root.section = expanded ? "" : "look"
                Column {
                    width: parent.width
                    Repeater {
                        model: root.defs.look
                        delegate: OptionRow {
                            required property var modelData
                            readonly property string style: root.spec ? root.defs.val(root.spec, "style") : "plain"
                            visible: modelData.key === "frost" ? style === "glass"
                                : modelData.key === "bgAlpha" ? (style === "card" || style === "glass" || style === "solid")
                                : modelData.key === "radius" ? (style !== "plain" || (!!root.spec && root.spec.type === "image"))
                                : modelData.key === "shadow" ? style !== "plain" : true
                            opt: modelData
                            value: root.spec ? root.defs.val(root.spec, modelData.key) : undefined
                            onChanged: v => root.editor.setOption(root.spec.id, modelData.key, v)
                        }
                    }
                }
            }
            DrawerSection {
                title: "Position"
                expanded: root.section === "position"; onToggled: root.section = expanded ? "" : "position"
                Column {
                    width: parent.width; spacing: 10
                    Text { text: "Snap to"; color: main.text; font { family: main.font; pixelSize: 13; weight: 500 } }
                    Grid {
                        columns: 3; spacing: 6
                        Repeater {
                            model: 9
                            delegate: Rectangle {
                                required property int index
                                width: 56; height: 38; radius: 10
                                color: am.containsMouse ? Qt.rgba(main.accent.r, main.accent.g, main.accent.b, 0.25) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.06)
                                Behavior on color { ColorAnimation { duration: main.ms(120) } }
                                Rectangle {
                                    width: 10; height: 10; radius: 5; color: am.containsMouse ? main.accent : main.muted
                                    x: (index % 3) * (parent.width - width - 12) / 2 + 6
                                    y: Math.floor(index / 3) * (parent.height - height - 12) / 2 + 6
                                }
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.editor.alignTo(root.spec.id, index % 3, Math.floor(index / 3)) }
                            }
                        }
                    }
                    Flow {
                        width: parent.width; spacing: 8
                        HButton { label: "Duplicate"; onClicked: root.editor.duplicate(root.spec.id) }
                        HButton { label: "Bring to front"; onClicked: root.editor.toFront(root.spec.id) }
                        HButton { label: "Reset widget"; onClicked: root.editor.resetWidget(root.spec.id) }
                    }
                }
            }
        }
    }
}
