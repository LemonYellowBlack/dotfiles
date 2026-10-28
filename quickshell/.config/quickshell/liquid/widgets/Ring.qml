import QtQuick
import qs.config

// A circular gauge with a gradient arc that sweeps in when it appears. `value` is 0..1;
// anything placed inside is centred over the ring.
Item {
    id: root
    property real value: 0
    property real thickness: 7
    property var colors: Theme.gAccent
    property bool glow: true
    default property alias content: inner.data
    property real shown: 0

    implicitWidth: 88
    implicitHeight: 88
    Behavior on shown { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Component.onCompleted: shown = Qt.binding(() => Math.max(0, Math.min(1, root.value)))
    onShownChanged: canvas.requestPaint()
    onColorsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, r = Math.min(w, h) / 2 - root.thickness / 2 - (root.glow ? 2 : 0);
            ctx.lineWidth = root.thickness;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.track;
            ctx.beginPath(); ctx.arc(w / 2, h / 2, r, 0, 2 * Math.PI); ctx.stroke();
            if (root.shown < 0.005) return;
            const g = ctx.createLinearGradient(0, 0, w, h);
            root.colors.forEach((c, i) => g.addColorStop(i / Math.max(1, root.colors.length - 1), c));
            ctx.strokeStyle = g;
            if (root.glow) { ctx.shadowColor = root.colors[Math.floor(root.colors.length / 2)]; ctx.shadowBlur = 8; }
            ctx.beginPath(); ctx.arc(w / 2, h / 2, r, -Math.PI / 2, -Math.PI / 2 + root.shown * 2 * Math.PI); ctx.stroke();
        }
    }
    Item { id: inner; anchors.fill: parent }
}
