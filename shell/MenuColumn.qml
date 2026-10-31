import QtQuick

// A stack of MenuSection blocks, in the order chosen in Settings > Menus. It places them itself (no layout engine),
// so a block whose height depends on its width can never make it loop.
Item {
    id: col
    property var shell: null
    property string menu: ""
    property real spacing: 8
    implicitHeight: 0
    readonly property var order: shell ? shell.menuOrder(menu) : []
    onOrderChanged: relayout()
    onWidthChanged: relayout()
    onSpacingChanged: relayout()
    Component.onCompleted: relayout()
    function relayout() { pending.restart(); }
    Timer { id: pending; interval: 0; onTriggered: col.doLayout() }
    function doLayout() {
        const list = [];
        for (let i = 0; i < children.length; i++) { const c = children[i]; if (c.section !== undefined && c.section !== "" && c.visible) list.push(c); }
        list.sort((a, b) => col.order.indexOf(a.section) - col.order.indexOf(b.section));
        let y = 0;
        for (const c of list) {
            if (c.y !== y) c.y = y;
            y += c.height + spacing;
        }
        const h = Math.max(0, y - spacing);
        if (implicitHeight !== h) implicitHeight = h;
        if (height !== h) height = h;
    }
}
