// qmllint disable
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification service: owns org.freedesktop.Notifications, keeps the history and decides what pops up.
Item {
    id: root
    property bool dnd: false
    property var history: []                      // plain copies, so the list outlives the app's own expiry timeout
    readonly property int unread: history.length
    property var toasts: []                       // notifications currently on screen (newest first)

    function show(n) {
        if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;
        root.toasts = [n].concat(root.toasts.filter(t => t !== n)).slice(0, 4);
    }
    function removeHistory(h) { root.history = root.history.filter(x => x !== h); }
    function hide(n) { root.toasts = root.toasts.filter(t => t !== n); }
    function clearAll() {
        root.toasts = [];
        root.history = [];
    }

    // Off in Settings -> System when another notification daemon (mako, dunst, ...) should keep the job.
    Loader {
        active: cfg.notifications
        sourceComponent: NotificationServer {
            id: server
            keepOnReload: false
            actionsSupported: true
            bodySupported: true
            bodyMarkupSupported: false
            imageSupported: true
            persistenceSupported: true
            onNotification: n => {
                n.tracked = true;
                root.history = [{ "appName": n.appName, "appIcon": n.appIcon, "summary": n.summary, "body": n.body,
                                  "image": n.image, "urgency": n.urgency }].concat(root.history).slice(0, 40);
                root.show(n);
            }
        }
    }
}
