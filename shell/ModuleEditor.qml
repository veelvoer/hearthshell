import QtQuick

// The bar's modules as lanes (left, middle, right) you drag between.
LaneEditor {
    id: ed
    required property var shell
    items: shell.cfg.modules
    allIds: shell.moduleOrder
    info: shell.moduleInfo
    trayText: "Not on the bar  ·  drag one up"
    onPlace: (id, lane, index) => shell.placeModule(id, lane, index)
}
