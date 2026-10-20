import Quickshell
import QtQuick

// The icon of an app, found from a window class (also works for web apps installed as apps).
Item {
    id: root
    property string appClass: ""
    property real size: 16
    readonly property var entry: appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null
    readonly property string iconName: entry && entry.icon ? entry.icon : appClass.toLowerCase()
    readonly property string resolved: appClass === "" ? "" : Quickshell.iconPath(iconName, true)
    width: size; height: size
    Image {
        anchors.fill: parent; source: root.resolved; sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true; smooth: true; visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent; radius: root.size * 0.28; color: main.accent; opacity: 0.55
        visible: root.appClass !== "" && root.resolved === ""
        Text { anchors.centerIn: parent; text: root.appClass.charAt(0).toUpperCase(); color: main.onAccent; font { family: main.font; pixelSize: root.size * 0.6; weight: 700 } }
    }
}
