pragma Singleton
import QtQuick
import Quickshell
import qs

// Solar elevation for the dashboard's sun arc and gammastep's ramp (3° down to −6°, 6500 K to 3500 K).
// NOAA's low-precision formulas, good to a minute or two.
Singleton {
    id: root

    function elev(d) {
        const rad = Math.PI / 180;
        const n = d.getTime() / 86400000 + 2440587.5 - 2451545.0;
        const L = (280.46 + 0.9856474 * n) % 360;
        const g = ((357.528 + 0.9856003 * n) % 360) * rad;
        const lam = (L + 1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * rad;
        const eps = (23.439 - 0.0000004 * n) * rad;
        const ra = Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam));
        const dec = Math.asin(Math.sin(eps) * Math.sin(lam));
        const gmst = (18.697374558 + 24.06570982441908 * n) % 24;
        const ha = (gmst * 15 + Host.lon) * rad - ra;
        const lat = Host.lat * rad;
        return Math.asin(Math.sin(lat) * Math.sin(dec) + Math.cos(lat) * Math.cos(dec) * Math.cos(ha)) / rad;
    }

    // Per-day values: sunrise, sunset, and elevation every 15 minutes. Refreshed when the date
    // changes; `now` ticks each minute so bindings on the current elevation follow along.
    property var day: ({ rise: null, set: null, curve: [] })
    property date now: new Date()
    property string key: ""
    function refresh() {
        now = new Date();
        if (key === now.toDateString()) return;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const at = m => elev(new Date(start + m * 60000));
        const cross = (rising) => {
            for (let m = 0; m < 1440; m += 2) {
                const a = at(m), b = at(m + 2);
                if (rising ? (a < -0.833 && b >= -0.833) : (a >= -0.833 && b < -0.833)) return new Date(start + (m + 1) * 60000);
            }
            return null;
        };
        const curve = [];
        for (let m = 0; m <= 1440; m += 15) curve.push(at(m));
        key = now.toDateString();
        day = { rise: cross(true), set: cross(false), curve: curve };
    }
    readonly property real elevation: elev(now)
    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    function kelvin(e) { return e >= 3 ? 6500 : (e <= -6 ? 3500 : Math.round((3500 + (e + 6) / 9 * 3000) / 50) * 50); }
    function hhmm(d) { return d ? String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0") : "--:--"; }
}
