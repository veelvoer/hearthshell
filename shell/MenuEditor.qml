import QtQuick

// Edits one island menu (Wi-Fi, Sound, ...): the real menu as a live preview, and next to it which sections it shows and in what
// order, its options and its width. Every change shows in the preview and in the real menu straight away.
Item {
    id: root
    required property var shell
    required property string menu
    readonly property var def: shell.menuDefs[menu]
    readonly property real frameW: shell.menuWidth(menu)
    readonly property bool below: width - frameW - 20 < 210
    readonly property var order: shell.menuOrder(menu)
    height: below ? frame.height + 16 + side.height : Math.max(frame.height, side.height)

    Rectangle {
        id: frame
        width: root.frameW; height: Math.min(560, Math.max(180, pv.item ? pv.item.wantedHeight : 300))
        radius: 28; color: main.bg; border.width: 1; border.color: main.border
        Behavior on width { NumberAnimation { duration: main.ms(200); easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: main.ms(220); easing.type: Easing.OutCubic } }
        clip: true
        Loader {
            id: pv
            anchors.fill: parent
            enabled: false
            sourceComponent: ({ "network": cNet, "bluetooth": cBt, "sound": cSnd, "display": cDsp, "notifications": cNot, "calendar": cCal,
                                "media": cMed, "theme": cThm, "wallpaper": cWal })[root.menu]
        }
        Text {
            visible: pv.status !== Loader.Ready; anchors.centerIn: parent; text: "No preview"; color: main.muted; font { family: main.font; pixelSize: 12 }
        }
    }
    Component { id: cNet; NetworkPopup { shell: root.shell } }
    Component { id: cBt; BluetoothPopup { shell: root.shell } }
    Component { id: cSnd; SoundPopup { shell: root.shell } }
    Component { id: cDsp; DisplayPopup { shell: root.shell } }
    Component { id: cNot; NotificationsPopup { shell: root.shell } }
    Component { id: cCal; CalendarPopup { shell: root.shell } }
    Component { id: cMed; MediaPopup { shell: root.shell } }
    Component { id: cThm; ThemePopup { shell: root.shell } }
    Component { id: cWal; WallpaperPopup { shell: root.shell } }

    Column {
        id: side
        x: root.below ? 0 : frame.width + 20; y: root.below ? frame.height + 16 : 0
        width: root.below ? root.width : root.width - frame.width - 20
        spacing: 12

        // width
        Rectangle {
            width: parent.width; height: 74; radius: 16; color: Qt.rgba(main.card.r, main.card.g, main.card.b, 1)
            Text { x: 14; y: 12; text: "Width"; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
            HSegment {
                x: 10; y: 34; options: root.shell.menuWidths.map(w => w[1]); segWidth: Math.floor((parent.width - 26) / 3)
                current: Math.max(0, root.shell.menuWidths.findIndex(w => w[0] === root.frameW))
                onPicked: i => root.shell.setMenuEntry(root.menu, { "width": root.shell.menuWidths[i][0] })
            }
        }

        // sections: show or hide, and move
        Rectangle {
            visible: root.def.sections.length > 1
            width: parent.width; height: visible ? 40 + root.order.length * 42 + 8 : 0; radius: 16; color: Qt.rgba(main.card.r, main.card.g, main.card.b, 1)
            Text { x: 14; y: 12; text: "Sections"; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
            Repeater {
                model: root.order
                delegate: Item {
                    id: srow
                    required property string modelData
                    required property int index
                    readonly property bool on: root.shell.menuSectionOn(root.menu, modelData)
                    readonly property string label: { for (const s of root.def.sections) if (s[0] === modelData) return s[1]; return modelData; }
                    x: 10; y: 38 + index * 42; width: parent.width - 20; height: 42
                    Text { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 130; elide: Text.ElideRight; text: srow.label
                        color: srow.on ? main.text : main.muted; font { family: main.font; pixelSize: 12; weight: 500 } }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: [-1, 1]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool can: modelData < 0 ? srow.index > 0 : srow.index < root.order.length - 1
                                width: 26; height: 26; radius: 13; anchors.verticalCenter: parent.verticalCenter
                                opacity: can ? 1 : 0.3
                                color: am.containsMouse && can ? Qt.rgba(main.text.r, main.text.g, main.text.b, 0.16) : Qt.rgba(main.text.r, main.text.g, main.text.b, 0.07)
                                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: modelData < 0 ? 0 : -1; text: modelData < 0 ? "↑" : "↓"; color: main.text; font { pixelSize: 12; weight: 700 } }
                                MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (parent.can) root.shell.moveMenuSection(root.menu, srow.modelData, parent.modelData) }
                            }
                        }
                        HToggle { anchors.verticalCenter: parent.verticalCenter; checked: srow.on; onToggled: v => root.shell.toggleMenuSection(root.menu, srow.modelData) }
                    }
                }
            }
        }

        // options
        Rectangle {
            visible: root.def.options.length > 0
            width: parent.width; height: visible ? 40 + root.def.options.length * 44 + 8 : 0; radius: 16; color: Qt.rgba(main.card.r, main.card.g, main.card.b, 1)
            Text { x: 14; y: 12; text: "Options"; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
            Repeater {
                model: root.def.options
                delegate: Item {
                    id: orow
                    required property var modelData
                    required property int index
                    readonly property var val: root.shell.menuOpt(root.menu, modelData.key)
                    x: 10; y: 38 + index * 44; width: parent.width - 20; height: 44
                    Text { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 150; elide: Text.ElideRight; text: orow.modelData.label
                        color: main.text; font { family: main.font; pixelSize: 12; weight: 500 } }
                    HToggle { visible: orow.modelData.kind === "toggle"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: !!orow.val; onToggled: v => root.shell.setMenuOpt(root.menu, orow.modelData.key, v) }
                    HStepper { visible: orow.modelData.kind === "stepper"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        implicitWidth: 112; width: 112; from: orow.modelData.min; to: orow.modelData.max; value: Number(orow.val)
                        onMoved: v => root.shell.setMenuOpt(root.menu, orow.modelData.key, v) }
                }
            }
        }

        HButton { label: "Reset this menu"; onClicked: root.shell.resetMenu(root.menu) }
    }
}
