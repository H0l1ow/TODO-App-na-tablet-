import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property int taskId: -1
    property string date: backend.today
    property var rows: backend.subTasks(taskId, date)
    title: "Podzadania"
    modal: true; focus: true
    width: Math.min(525, (parent ? parent.width : 550)-24)
    height: Math.min(510, (parent ? parent.height : 540)-24)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    standardButtons: Dialog.NoButton
    padding: 17; background: Rectangle { radius: 16; color: Theme.surface; border.color: Theme.border }
    Connections { target: backend; function onDataChanged() { root.rows=backend.subTasks(root.taskId,root.date) } }
    onOpened: rows=backend.subTasks(taskId,date)
    contentItem: ColumnLayout { spacing: 11
        Text { text: "Lista etapów osobna dla każdego dnia powtarzającego się zadania.";
            Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); color: Theme.muted }
        ListView { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 7
            model: root.rows
            delegate: RowLayout { width: ListView.view ? ListView.view.width-6 : 460; height: 56
                CheckBox { text: modelData.title; checked: modelData.done; Layout.fillWidth: true;
                    font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); onToggled: backend.setSubTaskDone(modelData.id,root.date,checked) }
                ActionButton { text: "×"; compact: true; danger: true; primary: false;
                    onClicked: backend.deleteSubTask(modelData.id) }
            }
        }
        RowLayout { Layout.fillWidth: true
            FormInput { id: subInput; Layout.fillWidth: true; maximumLength: 130; placeholderText: "Dodaj etap...";
                onAccepted: addStep() }
            ActionButton { text: "+ Dodaj"; compact: true; onClicked: addStep() }
        }
        ActionButton { Layout.fillWidth: true; text: "Gotowe"; primary: false; onClicked: root.close() }
    }
    function addStep() { if (backend.addSubTask(taskId,subInput.text)) subInput.clear() }
}
