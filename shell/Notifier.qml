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
    // Notifications on screen, newest first. Each one keeps its own pop-up (a changing array would rebuild every pop-up and restart
    // its timer), and when more arrive than fit, the extra ones wait in a queue and appear as room frees up: none is lost.
    readonly property int maxToasts: 4
    property var queued: []
    property var byKey: ({})                      // key -> notification object (never changes for a key, so nothing needs to notify)
    property int nextKey: 1
    readonly property alias toastModel: toastModel
    readonly property int toastCount: toastModel.count
    ListModel { id: toastModel }

    function indexOfN(n) { for (let i = 0; i < toastModel.count; i++) if (root.byKey[toastModel.get(i).tk] === n) return i; return -1; }
    function place(n, atEnd) {
        const k = root.nextKey++;
        root.byKey[k] = n;
        if (atEnd) toastModel.append({ "tk": k }); else toastModel.insert(0, { "tk": k });
    }
    function show(n) {
        if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;
        const i = root.indexOfN(n);
        if (i >= 0) { toastModel.move(i, 0, 1); return; }
        if (root.queued.indexOf(n) >= 0) return;
        if (toastModel.count >= root.maxToasts) root.queued = root.queued.concat([n]); else place(n, false);
    }
    property int nextUid: 1
    function removeHistory(h) { root.history = root.history.filter(x => x.uid !== h.uid); }
    function hide(n) {
        root.queued = root.queued.filter(q => q !== n);
        const i = root.indexOfN(n);
        if (i < 0) return;
        toastModel.remove(i, 1);
        if (root.queued.length > 0 && toastModel.count < root.maxToasts) {
            const next = root.queued[0];
            root.queued = root.queued.slice(1);
            place(next, true);      // at the end: it takes the place of the one that left, so the stack does not jump
        }
    }
    function clearAll() {
        toastModel.clear();
        root.queued = [];
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
                root.history = [{ "uid": root.nextUid++, "appName": n.appName, "appIcon": n.appIcon, "summary": n.summary, "body": n.body,
                                  "image": n.image, "urgency": n.urgency }].concat(root.history).slice(0, 40);
                root.show(n);
            }
        }
    }
}
