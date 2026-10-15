import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Item {
    id: root
    property var item: ({})
    property bool canRemove: false
    property bool canAdjust: false
    signal checkRequested(int itemId, bool bought)
    signal removeRequested(int itemId)
    signal quantityRequested(int itemId, string newQuantity)
    implicitHeight: 63
    function changedQuantity(delta) {
        var q = (item.quantity || "").trim()
        var match = /^(\d+)(.*)$/.exec(q)
        var num = match ? parseInt(match[1]) : 1
        var unit = match ? match[2] : ""
        root.quantityRequested(item.id, "" + Math.max(1,num+delta) + unit)
    }
    RowLayout { anchors.fill: parent; spacing: 9
        Rectangle { Layout.preferredWidth: 43; Layout.preferredHeight: 43; radius: 11;
            border.color: item.bought ? Theme.accent : Theme.border; border.width: 2;
            color: item.bought ? Theme.accent : Theme.surfaceMuted
            Text { anchors.centerIn: parent; text: "✓"; visible: !!item.bought;
                font.pixelSize: Math.max(11, Math.round(17 * backend.fontScale / 100)); font.bold: true; color: Theme.accentText }
            MouseArea { anchors.fill: parent; onClicked: root.checkRequested(root.item.id, !root.item.bought) }
        }
        ColumnLayout { Layout.fillWidth: true; spacing: 2
            Text { text: root.item.name || ""; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); font.bold: !root.item.bought;
                font.strikeout: !!root.item.bought; color: root.item.bought ? Theme.muted : Theme.text;
                elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.item.category || ""; font.pixelSize: Math.max(11, Math.round(11 * backend.fontScale / 100)); color: Theme.muted; Layout.fillWidth: true;
                visible: root.canAdjust }
        }
        ActionButton { text: "−"; compact: true; primary: false; implicitWidth: 44;
            visible: root.canAdjust; onClicked: root.changedQuantity(-1) }
        Text { text: root.item.quantity || "1"; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.text;
            Layout.preferredWidth: root.canAdjust ? 39 : 42; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
        ActionButton { text: "+"; compact: true; primary: false; implicitWidth: 44;
            visible: root.canAdjust; onClicked: root.changedQuantity(1) }
        ActionButton { text: "×"; compact: true; primary: false; danger: true; implicitWidth: 44;
            visible: root.canRemove; onClicked: root.removeRequested(root.item.id) }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
}
