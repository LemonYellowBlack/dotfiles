pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// The notification daemon (in place of mako). New notifications pop out of the island and stay
// in the control center until dismissed. The bin/ scripts' one-line status popups (a sync tag and
// no body) only flash in the island, and ones carrying a value hint become an island OSD.
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: n => root.incoming(n)
    }

    function incoming(n) {
        const tag = n.hints["x-canonical-private-synchronous"] || "";
        if (tag) {
            for (const o of server.trackedNotifications.values)
                if (o !== n && o.hints["x-canonical-private-synchronous"] === tag) o.dismiss();
        }
        const value = n.hints["value"];
        if (value !== undefined) {
            Shell.osd(Icons.vol, Number(value) / 100, Theme.gBlue, n.summary.replace(/^\W+\s*/, ""));
            return;
        }
        if (tag && !n.body) {
            Shell.msg("", n.summary, Theme.blue);
            return;
        }
        n.tracked = true;
        arrived[n.id] = Date.now();
        now = Date.now();
        if (!Toggles.dnd || n.urgency === NotificationUrgency.Critical)
            Shell.show({ kind: "note", note: n }, n.urgency === NotificationUrgency.Critical ? 9000 : 5200);
    }

    function dismiss(n) { n.dismiss(); }
    function clear() { for (const n of server.trackedNotifications.values.slice()) n.dismiss(); }
    // Quickshell doesn't timestamp notifications, so note when each arrived.
    property var arrived: ({})
    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = Date.now() }
    function ago(n) {
        const t = arrived[n.id];
        if (!t) return "";
        const m = Math.floor((now - t) / 60000);
        return m < 1 ? "now" : (m < 60 ? m + "m" : Math.floor(m / 60) + "h");
    }
}
