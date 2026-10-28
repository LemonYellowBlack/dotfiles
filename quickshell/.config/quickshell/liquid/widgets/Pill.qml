import QtQuick
import QtQuick.Layouts
import qs.config

// A bar module: a rounded pill that lights up on hover and while its drawer is open.
Rectangle {
    id: root
    property bool active: false
    property int pad: 12
    readonly property alias hovered: mouse.containsMouse
    default property alias content: row.data
    signal clicked()

    implicitHeight: 30
    implicitWidth: row.implicitWidth + pad * 2
    radius: 15
    color: active ? Theme.a(Theme.accent, 0.2) : (mouse.containsMouse ? Theme.pillHover : Theme.pill)
    border.width: active || mouse.containsMouse ? 1 : 0
    border.color: Theme.a(Theme.accent, active ? 0.55 : 0.3)
    scale: mouse.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

    RowLayout { id: row; anchors.centerIn: parent; spacing: 8 }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
