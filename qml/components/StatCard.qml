import QtQuick 2.12
import QtQuick.Layouts 1.12
import "."

Rectangle {
    id: card
    property string caption: ""
    property string amount: "0"
    property string note: ""
    implicitHeight: 124
    radius: 17
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 19
        spacing: 6
        Text { text: card.caption; font.pixelSize: 13; font.bold: true; color: Theme.muted }
        Text { text: card.amount; font.pixelSize: 29; font.bold: true; color: Theme.text }
        Text { text: card.note; font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true }
    }
}
