import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property int taskId: -1
    property string taskTitle: ""
    property int currentMemberId: -1
    title: "Przypisz zadanie"
    modal: true
    dim: true
    focus: true
    width: Math.min(390, (parent ? parent.width : 430) - 30)
    x: parent ? (parent.width - width)/2 : 0
    y: parent ? (parent.height - height)/2 : 0
    padding: 18
    standardButtons: Dialog.NoButton
    background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: 17 }
    contentItem: Column {
        width: parent ? parent.width : 340
        spacing: 10
        Text { width: parent.width; text: root.taskTitle; color: Theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
        Text { text: "Wybierz osobę lub wspólne zadanie:"; color: Theme.text; font.pixelSize: 13 }
        Repeater {
            model: backend.assignees
            delegate: ActionButton {
                width: parent.width
                height: 49
                text: (root.currentMemberId === modelData.id ? "✓  " : "") + modelData.name
                primary: root.currentMemberId === modelData.id
                onClicked: {
                    if (backend.setTaskAssignee(root.taskId, modelData.id)) root.close()
                }
            }
        }
        ActionButton { width: parent.width; text: "Anuluj"; compact: true; primary: false; onClicked: root.close() }
    }
}
