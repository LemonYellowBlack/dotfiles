import QtQuick
import qs.config

// A smooth area chart (Catmull-Rom through the samples) with a fading fill, a glowing line and
// a dot on the latest value. `limit` draws a dashed line at that value.
Item {
    id: root
    property var values: []
    property real lo: 0
    property real hi: 100
    property color color: Theme.blue
    property real limit: NaN
    property color limitColor: Theme.red
    implicitHeight: 48
    onValuesChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const v = root.values, w = width, h = height;
            const y = x => h - 4 - (Math.min(root.hi, Math.max(root.lo, x)) - root.lo) / (root.hi - root.lo) * (h - 8);
            if (!isNaN(root.limit)) {
                ctx.strokeStyle = Theme.a(root.limitColor, 0.5); ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
                ctx.beginPath(); ctx.moveTo(0, y(root.limit)); ctx.lineTo(w, y(root.limit)); ctx.stroke(); ctx.setLineDash([]);
            }
            if (v.length < 2) return;
            const pts = v.map((x, i) => [i * w / (v.length - 1), y(x)]);
            const path = () => {
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 0; i < pts.length - 1; i++) {
                    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
                    ctx.bezierCurveTo(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6, p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1]);
                }
            };
            const fill = ctx.createLinearGradient(0, 0, 0, h);
            fill.addColorStop(0, Theme.a(root.color, 0.42));
            fill.addColorStop(1, Theme.a(root.color, 0));
            ctx.fillStyle = fill;
            ctx.beginPath(); path(); ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath(); ctx.fill();
            ctx.strokeStyle = root.color; ctx.lineWidth = 2; ctx.lineJoin = "round";
            ctx.shadowColor = root.color; ctx.shadowBlur = 6;
            ctx.beginPath(); path(); ctx.stroke();
            const last = pts[pts.length - 1];
            ctx.fillStyle = root.color;
            ctx.beginPath(); ctx.arc(Math.min(last[0], w - 4), last[1], 3.5, 0, 2 * Math.PI); ctx.fill();
        }
    }
}
