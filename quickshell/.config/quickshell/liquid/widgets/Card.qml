import QtQuick
import QtQuick.Layouts
import qs.config

// A rounded panel inside a drawer; children stack in a column.
Rectangle {
    id: root
    property int pad: 14
    property alias spacing: col.spacing
    default property alias content: col.data
    radius: 18
    color: Theme.card
    implicitHeight: col.implicitHeight + pad * 2
    implicitWidth: col.implicitWidth + pad * 2
    ColumnLayout { id: col; anchors.fill: parent; anchors.margins: root.pad; spacing: 10 }
}
