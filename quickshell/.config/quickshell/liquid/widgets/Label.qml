import QtQuick
import QtQuick.Layouts
import qs.config

// A section label: small caps on the left, a fading rule, optional note on the right.
RowLayout {
    id: root
    property string text
    property string note
    spacing: 8
    T { text: root.text.toUpperCase(); font.pixelSize: 11; font.letterSpacing: 1; color: Theme.textMuted }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Theme.a(Theme.accent, 0.3) } GradientStop { position: 1; color: "transparent" } }
    }
    T { visible: root.note !== ""; text: root.note; font.pixelSize: 11; color: Theme.textMuted }
}
