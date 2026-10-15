import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

TextField {
    id: control
    implicitHeight: 46
    selectByMouse: true
    font.family: "Segoe UI"
    font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100))
    color: Theme.text
    placeholderTextColor: Theme.muted
    leftPadding: 14
    rightPadding: 14
    onActiveFocusChanged: if (activeFocus) Qt.inputMethod.show()
    background: Rectangle {
        radius: 10
        color: Theme.surfaceMuted
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.border
    }
}
