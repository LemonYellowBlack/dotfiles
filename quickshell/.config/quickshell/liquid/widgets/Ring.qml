import QtQuick
import qs.config

// A circular gauge with a gradient arc that sweeps in when it appears. `value` is 0..1;
// anything placed inside is centred over the ring. The sweep and the Canvas repaint only run
// while the ring is on screen: values arrive every second, so a hidden ring would otherwise
// animate (and repaint the whole shell surface) almost all the time. `animated: false` for
// rings too small for a sweep to show, which then repaint once per change.
Item {
    id: root
    property real value: 0
    property real thickness: 7
    property var colors: Theme.gAccent
    property bool glow: true
    property bool animated: true
    default property alias content: inner.data
    property real shown: 0

    implicitWidth: 88
    implicitHeight: 88
    Behavior on shown { enabled: root.animated && root.visible; NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Component.onCompleted: shown = Qt.binding(() => Math.max(0, Math.min(1, root.value)))
    onShownChanged: if (visible) canvas.requestPaint()
    onColorsChanged: if (visible) canvas.requestPaint()
    onWidthChanged: if (visible) canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()

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
