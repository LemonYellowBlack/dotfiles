import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config

// An app's theme icon, or a gradient squircle with a Lucide glyph when there's none.
Item {
    id: root
    property string iconName
    property string glyph
    property var colors: Theme.gAccent
    property real size: 36
    readonly property string source: !iconName ? "" : (iconName.startsWith("/") ? "file://" + iconName : (iconName.indexOf("://") > 0 ? iconName : Quickshell.iconPath(iconName, true)))
    implicitWidth: size
    implicitHeight: size
    IconImage { anchors.fill: parent; source: root.source; visible: root.source !== ""; asynchronous: true }
    Rectangle {
        anchors.fill: parent
        visible: root.source === ""
        radius: root.size / 3
        gradient: Grad { colors: root.colors }
        Icon { anchors.centerIn: parent; path: root.glyph; size: root.size / 2; stroke: 2; color: Theme.textOnAccent }
        T { anchors.centerIn: parent; visible: root.glyph === ""; text: (root.iconName || "?").slice(0, 1).toUpperCase(); color: Theme.textOnAccent; font.weight: Font.Bold }
    }
}
