import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "."

Dialog {
    id: root
    property int taskId: -1
    property string initialDate: backend.today
    property var assigneeOptions: backend.assignees
    property var categoryOptions: [{"id": -1, "name": "Bez kategorii"}].concat(backend.categories)
    property int mask: 0
    signal saved()
    title: taskId > 0 ? "Edytuj zadanie" : "Nowe zadanie"
    modal: true; dim: true; focus: true
    width: Math.min(600, (parent ? parent.width : 640) - 20)
    height: Math.min(700, (parent ? parent.height : 730) - 20)
    x: parent ? (parent.width-width)/2 : 0
    y: parent ? (parent.height-height)/2 : 0
    padding: 18
    standardButtons: Dialog.NoButton
    background: Rectangle { radius: 18; color: Theme.surface; border.color: Theme.border }
    function setIndexById(box, options, id) {
        box.currentIndex = 0
        for (var i=0; i<options.length; ++i)
            if (options[i].id === id) { box.currentIndex = i; break }
    }
    onOpened: {
        var t = taskId > 0 ? backend.taskDetails(taskId) : ({})
        nameInput.text = t.title || ""
        startInput.text = t.startDate || initialDate
        endInput.text = t.endDate || ""
        noteInput.text = t.note || ""
        timeInput.text = t.dueTime || ""
        intervalInput.value = Math.max(1, t.intervalDays || 2)
        mask = t.weekdays || backend.weekdayBit(startInput.text)
        var codes = ["once", "daily", "weekly", "interval", "monthly"]
        repeat.currentIndex = Math.max(0, codes.indexOf(t.recurrence || "once"))
        setIndexById(assignee, assigneeOptions, t.memberId === undefined ? -1 : t.memberId)
        setIndexById(category, categoryOptions, t.categoryId === undefined ? -1 : t.categoryId)
        warning.text = ""
    }
    function save() {
        var codes = ["once", "daily", "weekly", "interval", "monthly"]
        var person = assigneeOptions[assignee.currentIndex].id
        var cat = categoryOptions[category.currentIndex].id
        var ok = taskId > 0
            ? backend.editTask(taskId, nameInput.text, startInput.text, codes[repeat.currentIndex], mask, person,
                               intervalInput.value, endInput.text, noteInput.text, cat, timeInput.text)
            : backend.createTask(nameInput.text, startInput.text, codes[repeat.currentIndex], mask, person,
                                 intervalInput.value, endInput.text, noteInput.text, cat, timeInput.text)
        if (ok) { root.saved(); root.close() }
        else warning.text = backend.errorMessage || "Nie udało się zapisać."
    }
    contentItem: ColumnLayout {
        spacing: 9
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: Math.min(root.width - 45, 620); spacing: 12
                Text { text: "Nazwa zadania"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                FormInput { id: nameInput; Layout.fillWidth: true; maximumLength: 160; placeholderText: "Co należy zrobić?" }
                RowLayout { Layout.fillWidth: true; spacing: 10
                    ColumnLayout { Layout.fillWidth: true
                        Text { text: "Data początku (RRRR-MM-DD)"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                        FormInput { id: startInput; Layout.fillWidth: true; inputMask: "0000-00-00;_" }
                    }
                    ColumnLayout { Layout.fillWidth: true
                        Text { text: "Data zakończenia (opcjonalnie)"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                        FormInput { id: endInput; Layout.fillWidth: true; placeholderText: "RRRR-MM-DD" }
                    }
                }
                RowLayout { Layout.fillWidth: true; spacing: 10
                    ColumnLayout { Layout.fillWidth: true
                        Text { text: "Przypisanie"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                        ComboBox { id: assignee; Layout.fillWidth: true; Layout.preferredHeight: 50; model: root.assigneeOptions; textRole: "name" }
                    }
                    ColumnLayout { Layout.fillWidth: true
                        Text { text: "Kategoria"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                        ComboBox { id: category; Layout.fillWidth: true; Layout.preferredHeight: 50; model: root.categoryOptions; textRole: "name" }
                    }
                }
                Text { text: "Powtarzanie"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                ComboBox { id: repeat; Layout.fillWidth: true; Layout.preferredHeight: 50;
                    model: ["Jednorazowo", "Codziennie", "Wybrane dni tygodnia", "Co N dni", "Co miesiąc"] }
                RowLayout { visible: repeat.currentIndex === 3; spacing: 15
                    Text { text: "Co ile dni:"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)) }
                    SpinBox { id: intervalInput; from: 1; to: 365; value: 2; editable: true; Layout.preferredWidth: 135; Layout.preferredHeight: 50 }
                }
                Row { visible: repeat.currentIndex === 2; spacing: 5
                    Repeater { model: ["Pn", "Wt", "Śr", "Cz", "Pt", "So", "Nd"]
                        delegate: Button { id: weekday; property int bit: 1 << index
                            width: Math.max(33, Math.min(59, (root.width - 62) / 7)); height: 46; text: modelData
                            background: Rectangle { radius: 10; color: (root.mask & weekday.bit) ? Theme.accent : Theme.surfaceMuted; border.color: Theme.border }
                            contentItem: Text { text: weekday.text; color: (root.mask & weekday.bit) ? Theme.accentText : Theme.text;
                                font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            onClicked: root.mask ^= bit
                        }
                    }
                }
                Text { text: "Godzina (opcjonalnie, HH:mm)"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                FormInput { id: timeInput; Layout.fillWidth: true; placeholderText: "Np. 18:30"; maximumLength: 5 }
                Text { text: "Notatka (opcjonalnie)"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                TextArea { id: noteInput; Layout.fillWidth: true; Layout.preferredHeight: 75; wrapMode: TextEdit.Wrap;
                    placeholderText: "Szczegóły obowiązku..."; color: Theme.text; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100));
                    background: Rectangle { color: Theme.surfaceMuted; radius: 10; border.color: Theme.border } }
            }
        }
        Text { id: warning; Layout.fillWidth: true; color: Theme.danger; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); wrapMode: Text.WordWrap }
        RowLayout { Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            ActionButton { text: "Anuluj"; primary: false; onClicked: root.close() }
            ActionButton { text: "Zapisz"; onClicked: root.save() }
        }
    }
}
