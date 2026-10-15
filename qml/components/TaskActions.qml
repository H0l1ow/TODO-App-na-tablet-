import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property var task: ({})
    property string day: backend.today
    property string destination: backend.dateOffset(day, 1)
    signal editRequested(int taskId)
    signal assignmentRequested(int taskId)
    signal subtasksRequested(int taskId, string day)
    signal success(string message)
    title: task.title || "Opcje zadania"
    modal: true; focus: true
    width: Math.min(465, (parent ? parent.width : 505) - 24)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 18; standardButtons: Dialog.NoButton
    background: Rectangle { radius: 18; color: Theme.surface; border.color: Theme.border }
    onOpened: { destination = backend.dateOffset(day, 1); targetInput.text = destination; hint.text = "" }
    contentItem: ColumnLayout {
        spacing: 12
        Text { text: "Kopiowanie tworzy nowy wpis. Przeniesienie zmienia datę istniejącego zadania.";
            color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
        ActionButton { text: "✎  Edytuj zadanie"; Layout.fillWidth: true; onClicked: { root.close(); root.editRequested(task.id) } }
        ActionButton { text: "Lista podzadań"; Layout.fillWidth: true; primary: false;
            onClicked: { root.close(); root.subtasksRequested(task.id, root.day) } }
        ActionButton { text: "Przypisz domownika"; Layout.fillWidth: true; primary: false;
            onClicked: { root.close(); root.assignmentRequested(task.id) } }
        Text { text: "Data docelowa (RRRR-MM-DD)"; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted }
        FormInput { id: targetInput; Layout.fillWidth: true; text: root.destination; onTextChanged: root.destination = text }
        RowLayout { Layout.fillWidth: true; spacing: 8
            ActionButton { Layout.fillWidth: true; text: "Kopiuj"; onClicked: {
                if (backend.copyTaskToDate(task.id, root.day, root.destination)) { root.success("Zadanie skopiowano."); root.close() }
                else hint.text = backend.errorMessage
            } }
            ActionButton { Layout.fillWidth: true; text: "Przenieś"; primary: false;
                enabled: task.recurrence === "once"
                onClicked: {
                    if (backend.moveTaskToDate(task.id, root.destination)) { root.success("Zadanie przeniesiono."); root.close() }
                    else hint.text = backend.errorMessage
                } }
        }
        RowLayout { Layout.fillWidth: true
            Text { text: "Lub skopiuj na kolejne"; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted }
            SpinBox { id: daysCount; from: 1; to: 31; value: 3;
                Layout.preferredWidth: 125; Layout.preferredHeight: 48; editable: true }
            ActionButton { text: "dni"; compact: true; primary: false;
                onClicked: { var r = backend.copyTaskForDays(task.id, root.day, daysCount.value)
                    if (r.ok) { root.success("Skopiowano na " + r.copied + " dni."); root.close() }
                    else hint.text = backend.errorMessage }
            }
        }
        ActionButton { text: task.skipped ? "Cofnij pominięcie" : "Oznacz jako pominięte";
            Layout.fillWidth: true; primary: false; onClicked: {
                if (backend.setTaskSkipped(task.id, root.day, !task.skipped)) { root.success("Zmieniono status."); root.close() }
                else hint.text = backend.errorMessage
            } }
        ActionButton { text: "Zarchiwizuj zadanie"; danger: true; primary: false;
            Layout.fillWidth: true; onClicked: archiveConfirm.open() }
        Text { id: hint; Layout.fillWidth: true; color: Theme.warning; wrapMode: Text.WordWrap; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
        ActionButton { text: "Zamknij"; primary: false; Layout.fillWidth: true; onClicked: root.close() }
        Dialog {
            id: archiveConfirm; modal: true; title: "Potwierdź archiwizację"
            standardButtons: Dialog.Yes | Dialog.No
            onAccepted: { if (backend.archiveTask(task.id)) { root.success("Zadanie zarchiwizowano."); root.close() } }
            contentItem: Text { text: "Zadanie przestanie pojawiać się w planie."; color: Theme.text;
                width: 270; wrapMode: Text.WordWrap }
        }
    }
}
