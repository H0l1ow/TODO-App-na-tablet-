import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Item {
    id: root
    property var item: ({})
    property bool canRemove: false
    signal checkRequested(int itemId, bool bought)
    signal removeRequested(int itemId)
    implicitHeight: 55
    RowLayout {
        anchors.fill: parent; spacing: 10
        Rectangle {
            Layout.preferredWidth: 25; Layout.preferredHeight: 25
            radius: 7; border.color: root.item.bought ? Theme.accent : Theme.border
            border.width: 1.5; color: root.item.bought ? Theme.accent : Theme.surface
            Text { text: "✓"; color: Theme.accentText; anchors.centerIn: parent; visible: !!root.item.bought; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: root.checkRequested(root.item.id, !root.item.bought) }
        }
        Text {
            text: root.item.name || ""; Layout.fillWidth: true
            font.pixelSize: 14; font.bold: !root.item.bought
            color: root.item.bought ? Theme.muted : Theme.text
            font.strikeout: !!root.item.bought; elide: Text.ElideRight
        }
        Text { text: root.item.quantity || ""; color: Theme.muted; font.pixelSize: 12 }
        Button {
            visible: root.canRemove
            implicitWidth: 26; implicitHeight: 30
            background: Rectangle { color: "transparent" }
            contentItem: Text { text: "×"; color: Theme.muted; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: root.removeRequested(root.item.id)
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
