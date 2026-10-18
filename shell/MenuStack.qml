// qmllint disable
import QtQuick

// Every bar menu in one place: the island and the classic pop-up host this, so a new menu is added once.
// `menu` names the one to show; the others stay loaded (but hidden) so opening never stutters.
Item {
    id: st
    property string menu: ""
    property bool settled: false
    property var shell: null
    property string from: ""                              // the menu this one was opened from ("" = the bar)
    signal requestMenu(string kind)
    signal requestClose()
    readonly property var item: menu === "network" ? net.item : menu === "bluetooth" ? bt.item : menu === "quick" ? quick.item
        : menu === "notifications" ? notif.item : menu === "calendar" ? cal.item : menu === "media" ? media.item
        : menu === "sound" ? sound.item : menu === "display" ? display.item : null
    readonly property bool typing: !!item && !!item.typing
    readonly property real wantedHeight: item ? item.wantedHeight : 0

    function glyphFor(k) {
        const cp = n => String.fromCodePoint(n);
        return k === "network" ? cp(0xF05A9) : k === "bluetooth" ? cp(0xF00AF) : k === "quick" ? cp(0xF0570)
            : k === "notifications" ? cp(0xF009A) : k === "calendar" ? cp(0xF00ED) : k === "media" ? cp(0xF075A)
            : k === "sound" ? cp(0xF057E) : k === "display" ? cp(0xF00E0) : "";
    }
    function titleFor(k) {
        return ({ "network": "Wi-Fi", "bluetooth": "Bluetooth", "quick": "Control Center", "notifications": "Notifications",
                  "calendar": "Calendar", "media": "Now playing", "sound": "Sound", "display": "Display" })[k] || "";
    }

    component Slot: Loader {
        required property string kind
        width: st.width; height: st.height
        asynchronous: true
        visible: st.menu === kind
    }
    Slot { id: net; kind: "network"; sourceComponent: NetworkPopup { active: st.menu === "network"; settled: active && st.settled } }
    Slot { id: bt; kind: "bluetooth"; sourceComponent: BluetoothPopup { active: st.menu === "bluetooth"; settled: active && st.settled } }
    Slot { id: quick; kind: "quick"
        sourceComponent: QuickPopup {
            active: st.menu === "quick"; settled: active && st.settled; shell: st.shell
            onRequestMenu: k => st.requestMenu(k)
            onRequestClose: st.requestClose()
        } }
    Slot { id: notif; kind: "notifications"
        sourceComponent: NotificationsPopup { active: st.menu === "notifications"; settled: active && st.settled; shell: st.shell; onRequestClose: st.requestClose() } }
    Slot { id: cal; kind: "calendar"
        sourceComponent: CalendarPopup { active: st.menu === "calendar"; settled: active && st.settled; shell: st.shell; onRequestClose: st.requestClose() } }
    Slot { id: media; kind: "media"
        sourceComponent: MediaPopup { active: st.menu === "media"; settled: active && st.settled; shell: st.shell } }
    Slot { id: sound; kind: "sound"
        sourceComponent: SoundPopup { active: st.menu === "sound"; settled: active && st.settled; shell: st.shell } }
    Slot { id: display; kind: "display"
        sourceComponent: DisplayPopup { active: st.menu === "display"; settled: active && st.settled; shell: st.shell } }
}
