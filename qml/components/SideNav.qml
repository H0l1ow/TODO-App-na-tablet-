import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Button {
    id: nav
    property string iconText: "•"
    property bool selected: false
    implicitHeight: 48
    LayoutMirroring.enabled: false
    background: Rectangle { color: nav.selected ? Theme.accentSoft : "transparent"; radius: 11 }
    contentItem: Row {
        spacing: 12
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        Text {
            text: nav.iconText
            width: 25
            font.family: "Segoe UI Symbol"
            font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100))
            color: nav.selected ? Theme.accent : Theme.muted
            horizontalAlignment: Text.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: nav.text
            font.family: "Segoe UI"
            font.bold: nav.selected
            font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100))
            color: nav.selected ? Theme.accent : Theme.muted
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
