import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property string sourceDate: backend.today
    property string destination: backend.dateOffset(sourceDate,1)
    signal copied(string message)
    title: "Kopiowanie całego dnia"
    modal: true; dim: true; focus: true
    width: Math.min(480, (parent ? parent.width : 520) - 24)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 18; standardButtons: Dialog.NoButton
    background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: 16 }
    onOpened: { destination = backend.dateOffset(sourceDate, 1); info.text = ""; filter.currentIndex = 0 }
    function execute(includeCompleted) {
        var choices = backend.assignees
        var person = filter.currentIndex === 0 ? -2 : choices[filter.currentIndex - 1].id
        var result = backend.copyDayToDate(sourceDate, destination, includeCompleted, person)
        if (!result.ok) { info.text = backend.errorMessage || "Niepoprawna data docelowa."; return }
        root.copied("Skopiowano " + result.copied + ", pominięto " + result.alreadyPresent + " duplikatów.")
        root.close()
    }
    contentItem: ColumnLayout {
        spacing: 14
        Text { text: "Źródło: " + backend.dateLabel(root.sourceDate); color: Theme.text;
            font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: "Kopiowanie nie usuwa oryginałów. Powtarzające się zadania nie będą dublowane.";
            color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        Text { text: "Data docelowa (RRRR-MM-DD):"; color: Theme.muted }
        FormInput { id: target; Layout.fillWidth: true; text: root.destination; onTextChanged: root.destination = text }
        Text { text: "Kogo kopiować?"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
        ComboBox { id: filter; Layout.fillWidth: true; Layout.preferredHeight: 50;
            model: [{"name": "Wszystkie osoby"}].concat(backend.assignees); textRole: "name" }
        ActionButton { Layout.fillWidth: true; text: "Kopiuj niewykonane"; onClicked: root.execute(false) }
        ActionButton { Layout.fillWidth: true; text: "Kopiuj wszystkie"; primary: false; onClicked: root.execute(true) }
        Text { id: info; color: Theme.warning; Layout.fillWidth: true; wrapMode: Text.WordWrap; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)) }
        ActionButton { Layout.fillWidth: true; text: "Anuluj"; primary: false; onClicked: root.close() }
    }
}
