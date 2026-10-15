import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property string targetDate: backend.today
    property string feedback: ""
    title: "Szablony całych dni"
    modal: true; focus: true
    width: Math.min(530, (parent ? parent.width : 560) - 26)
    height: Math.min(550, (parent ? parent.height : 580) - 24)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 18; standardButtons: Dialog.NoButton
    background: Rectangle { color: Theme.surface; radius: 18; border.color: Theme.border }
    onOpened: feedback = ""
    contentItem: ColumnLayout {
        spacing: 12
        Text { text: "Plan: " + backend.dateLabel(root.targetDate); color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100));
            Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: "Zapisz obecny plan jako szablon lub wstaw gotowy zestaw zadań na wybraną datę.";
            color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        RowLayout { Layout.fillWidth: true
            FormInput { id: templateName; Layout.fillWidth: true; placeholderText: "Nazwa, np. Poniedziałek"; maximumLength: 70 }
            ActionButton { text: "Zapisz dzień"; compact: true; onClicked: {
                if (backend.saveDayTemplate(templateName.text, root.targetDate)) {
                    root.feedback = "Zapisano szablon."; templateName.clear()
                } else root.feedback = backend.errorMessage || "Nie można zapisać szablonu."
            } }
        }
        Text { text: "Zapisane szablony"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(17 * backend.fontScale / 100)); font.bold: true }
        ListView { id: list; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 8;
            model: backend.dayTemplates
            delegate: RowLayout { width: ListView.view ? ListView.view.width-6 : 450; height: 56
                Text { text: modelData.name + " (" + modelData.count + ")"; Layout.fillWidth: true;
                    color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); elide: Text.ElideRight }
                ActionButton { text: "Wstaw"; compact: true; onClicked: {
                    var r = backend.applyDayTemplate(modelData.id, root.targetDate)
                    root.feedback = r.ok ? "Dodano: " + r.copied + ", duplikaty: " + r.alreadyPresent : "Błąd szablonu."
                } }
                ActionButton { text: "Usuń"; danger: true; compact: true; primary: false;
                    onClicked: backend.deleteDayTemplate(modelData.id) }
            }
        }
        Text { text: root.feedback; Layout.fillWidth: true; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); wrapMode: Text.WordWrap }
        ActionButton { Layout.fillWidth: true; text: "Gotowe"; primary: false; onClicked: root.close() }
    }
}
