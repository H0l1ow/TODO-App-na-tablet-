import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Button {
    id: control
    property bool primary: true
    property bool compact: false
    property bool danger: false
    implicitHeight: compact ? 42 : 47
    implicitWidth: Math.max(compact ? 70 : 96, title.implicitWidth + (compact ? 22 : 32))
    padding: 8
    font.family: "Segoe UI"
    font.pixelSize: compact ? 12 : 14
    font.bold: primary
    background: Rectangle {
        radius: 11
        color: !control.enabled ? Theme.surfaceMuted
            : control.down ? Theme.accentSoft
            : control.danger ? Theme.warningSoft
            : control.primary ? Theme.accent : Theme.surfaceMuted
        border.color: control.primary ? "transparent" : Theme.border
        border.width: control.primary ? 0 : 1
    }
    contentItem: Text {
        id: title
        text: control.text
        font: control.font
        color: !control.enabled ? Theme.disabled
            : control.danger ? Theme.danger
            : control.primary ? Theme.accentText : Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
