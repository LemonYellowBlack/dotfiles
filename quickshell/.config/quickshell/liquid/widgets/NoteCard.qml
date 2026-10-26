import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// One notification in the control center: icon, app and age, summary, body and its actions.
// Slides in from the right; dismissing it is the notification server's job.
Rectangle {
    id: root
    property var note: null
    radius: 18
    color: Qt.rgba(0.165, 0.165, 0.216, 0.5)
    implicitHeight: row.implicitHeight + 24
    opacity: 0
    transform: Translate {
        id: shift
        x: 30
        Behavior on x { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
    }
    Component.onCompleted: { opacity = 1; shift.x = 0; }
    Behavior on opacity { NumberAnimation { duration: 380 } }

    RowLayout {
        id: row
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 12
        AppIcon {
            Layout.alignment: Qt.AlignTop
            size: 34
            iconName: root.note ? (root.note.image || root.note.appIcon) : ""
            glyph: Icons.bell
            colors: Theme.gWarm
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            RowLayout {
                Layout.fillWidth: true
                T { text: root.note ? root.note.appName + (Notifs.ago(root.note) ? " · " + Notifs.ago(root.note) : "") : ""; font.pixelSize: 11; color: Theme.muted; Layout.fillWidth: true }
                IconBtn { implicitWidth: 24; implicitHeight: 24; icon: Icons.x; iconSize: 12; onClicked: if (root.note) root.note.dismiss() }
            }
            T { text: root.note ? root.note.summary : ""; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
            T { visible: text !== ""; text: root.note ? root.note.body : ""; font.pixelSize: 12; color: Theme.old; Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4; lineHeight: 1.15 }
            Flow {
                visible: root.note && root.note.actions.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Repeater {
                    model: root.note ? root.note.actions : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        implicitHeight: 26
                        implicitWidth: actionText.implicitWidth + 22
                        radius: 13
                        color: index === 0 ? "transparent" : (actionMouse.containsMouse ? Theme.a(Theme.blue, 0.25) : Qt.rgba(0.212, 0.212, 0.275, 0.7))
                        gradient: index === 0 ? first : null
                        Grad { id: first; colors: [Theme.blue, Theme.violet] }
                        T { id: actionText; anchors.centerIn: parent; text: modelData.text; font.pixelSize: 12; color: index === 0 ? Theme.ink0 : Theme.fg; font.weight: index === 0 ? Font.DemiBold : Font.Normal }
                        MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.invoke() }
                    }
                }
            }
        }
    }
}
