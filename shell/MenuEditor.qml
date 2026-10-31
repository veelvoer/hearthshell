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
    readonly property var sectionInfo: { const o = {}; for (const x of def.sections) o[x[0]] = { "label": x[1] }; return o; }
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

        // sections: drag to reorder, drag down to hide
        Rectangle {
            visible: root.def.sections.length > 1
            width: parent.width; height: visible ? 38 + secEd.height + 14 : 0; radius: 16; color: Qt.rgba(main.card.r, main.card.g, main.card.b, 1)
            Text { x: 14; y: 12; text: "Sections"; color: main.text; font { family: main.font; pixelSize: 13; weight: 600 } }
            LaneEditor {
                id: secEd
                x: 10; y: 36; width: parent.width - 20
                lanes: ["on"]; laneNames: ({ "on": "Shown" })
                items: ({ "on": root.shell.menuShownList(root.menu) })
                allIds: root.shell.menuOrder(root.menu)
                info: root.sectionInfo
                trayText: "Hidden  ·  drag one up to show it"
                onPlace: (id, lane, index) => root.shell.placeMenuSection(root.menu, id, lane, index)
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
                    Text { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - (orow.modelData.kind === "stepper" ? 130 : 64); wrapMode: Text.WordWrap; text: orow.modelData.label
                        color: main.text; font { family: main.font; pixelSize: 12; weight: 500 } }
                    HToggle { visible: orow.modelData.kind === "toggle"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        checked: !!orow.val; onToggled: v => root.shell.setMenuOpt(root.menu, orow.modelData.key, v) }
                    HStepper { visible: orow.modelData.kind === "stepper"; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        implicitWidth: 112; width: 112; from: orow.modelData.min || 0; to: orow.modelData.max || 1; value: Number(orow.val) || 0
                        onMoved: v => root.shell.setMenuOpt(root.menu, orow.modelData.key, v) }
                }
            }
        }

        HButton { label: "Reset this menu"; onClicked: root.shell.resetMenu(root.menu) }
    }
}
