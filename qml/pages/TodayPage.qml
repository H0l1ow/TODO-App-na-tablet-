import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

Item {
    id: page
    signal openShopping()
    property int memberFilter: -2
    property var tasks: backend.tasksForDateFiltered(backend.today, memberFilter)
    property var counts: backend.dashboard
    property var favorites: backend.quickTemplates(0)
    property var overdue: backend.overdueTasks()
    property var selectedOverdue: []
    property var notesList: backend.notes()
    Connections { target: backend
        function onDataChanged() {
            page.notesList = backend.notes()
            page.favorites = backend.quickTemplates(0)
            page.overdue = backend.overdueTasks()
            var ids = page.overdue.map(function(t) { return t.id })
            page.selectedOverdue = page.selectedOverdue.filter(function(id) { return ids.indexOf(id) !== -1 })
        }
    }
    property string statusMessage: ""

    Flickable {
        id: scroll
        anchors.fill: parent; clip: true
        contentWidth: width; contentHeight: content.implicitHeight + 56
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: content; x: 24; y: 18; width: scroll.width-48; spacing: 16
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    Text { text: "Dzisiaj"; font.pixelSize: Math.max(11, Math.round(30 * backend.fontScale / 100)); font.bold: true; color: Theme.text }
                    Text { text: backend.todayLabel; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); color: Theme.muted }
                }
                ActionButton { text: "+ Szybkie zadanie"; onClicked: openQuickTask() }
                ActionButton { text: "+ Własne"; primary: false; onClicked: newTask() }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Text { text: counts.done + " / " + counts.total + " wykonanych"; color: Theme.text;
                    font.pixelSize: Math.max(11, Math.round(17 * backend.fontScale / 100)); font.bold: true }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 12; radius: 6; color: Theme.surfaceMuted
                    Rectangle { height: parent.height; radius: 6; color: Theme.accent;
                        width: counts.total ? parent.width*counts.done/counts.total : 0 }
                }
                Text { text: counts.overdue + " zaległych"; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100));
                    color: counts.overdue ? Theme.warning : Theme.muted }
            }
            RowLayout { Layout.fillWidth: true; spacing: 8
                ActionButton { text: "Kopiuj dzień"; primary: false; compact: true; onClicked: {
                    copyDayDialog.sourceDate = backend.today; copyDayDialog.open()
                } }
                ActionButton { text: "Szablon dnia"; primary: false; compact: true; onClicked: {
                    dayTemplatesDialog.targetDate = backend.today; dayTemplatesDialog.open()
                } }
                ActionButton { text: "Cofnij ↶"; primary: false; compact: true;
                    enabled: backend.undoLabel.length > 0; onClicked: backend.undoLast() }
                Item { Layout.fillWidth: true }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: favoritesRow.implicitHeight + 25;
                radius: 14; color: Theme.accentSoft; border.color: Theme.border
                ColumnLayout { id: favoritesRow; anchors.left: parent.left; anchors.right: parent.right;
                    anchors.top: parent.top; anchors.margins: 12; spacing: 9
                    Text { text: "★  SZYBKIE SKRÓTY"; color: Theme.accent; font.pixelSize: Math.max(11, Math.round(12 * backend.fontScale / 100)); font.bold: true }
                    Flow { Layout.fillWidth: true; spacing: 8; Layout.preferredHeight: Math.max(57, childrenRect.height + 2)
                        Repeater { model: Math.min(page.favorites.length, 5)
                            delegate: ActionButton {
                                text: "+ " + page.favorites[index].title; primary: false; compact: true;
                                implicitHeight: 51
                                onClicked: {
                                    if (backend.addFromQuickTemplate(page.favorites[index].id, backend.today, -2))
                                        page.statusMessage = "Dodano: " + page.favorites[index].title
                                }
                            }
                        }
                    }
                }
            }
            RowLayout { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 14
                Rectangle { Layout.fillWidth: true; Layout.preferredWidth: 660;
                    Layout.preferredHeight: taskColumn.implicitHeight + 36;
                    color: Theme.surface; border.color: Theme.border; radius: 16
                    ColumnLayout { id: taskColumn; anchors.fill: parent; anchors.margins: 18; spacing: 11
                        RowLayout { Layout.fillWidth: true
                            Text { text: "Zadania na dziś"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(21 * backend.fontScale / 100)); font.bold: true; Layout.fillWidth: true }
                            ComboBox { id: filterBox; Layout.preferredWidth: Math.min(185, taskColumn.width*0.37);
                                Layout.preferredHeight: 50;
                                model: [{"id": -2, "name": "Wszystkie"}].concat(backend.assignees)
                                textRole: "name"
                                onCurrentIndexChanged: {
                                    var options = [{"id": -2, "name": "Wszystkie"}].concat(backend.assignees)
                                    page.memberFilter = currentIndex >= 0 && currentIndex < options.length ? options[currentIndex].id : -2
                                }
                            }
                        }
                        Text { Layout.fillWidth: true; visible: page.tasks.length === 0;
                            text: "Brak zadań w tym widoku. Dodaj zadanie, wybierając skrót lub wpisując tekst.";
                            wrapMode: Text.WordWrap; font.pixelSize: Math.max(11, Math.round(15 * backend.fontScale / 100)); color: Theme.muted }
                        ListView { id: taskList; Layout.fillWidth: true;
                            Layout.preferredHeight: Math.min(620, Math.max(80, page.tasks.length * 80));
                            clip: true; spacing: 2; model: page.tasks
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                            delegate: TaskRow {
                                width: ListView.view ? ListView.view.width - 5 : 500
                                task: modelData
                                onCheckRequested: backend.setTaskDone(taskId, backend.today, done)
                                onAssigneeRequested: editAssignee(task)
                                onActionRequested: openActions(task)
                            }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            FormInput { id: quickInput; Layout.fillWidth: true; maximumLength: 160;
                                placeholderText: "Niestandardowe zadanie..."; onAccepted: addCustom() }
                            ActionButton { text: "+ Dodaj"; compact: true; onClicked: addCustom() }
                        }
                        RowLayout { Layout.fillWidth: true
                            Text { text: "Przypisz nowe:"; color: Theme.muted; font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)) }
                            ComboBox { id: assigneeBox; Layout.fillWidth: true; Layout.preferredHeight: 48;
                                model: backend.assignees; textRole: "name" }
                        }
                    }
                }
                Rectangle { Layout.preferredWidth: Math.min(330, content.width*0.35); Layout.minimumWidth: 260;
                    Layout.preferredHeight: shopColumn.implicitHeight + 32;
                    color: Theme.surface; border.color: Theme.border; radius: 16
                    ColumnLayout { id: shopColumn; anchors.fill: parent; anchors.margins: 16; spacing: 10
                        RowLayout { Layout.fillWidth: true
                            Text { text: "Zakupy"; font.pixelSize: Math.max(11, Math.round(20 * backend.fontScale / 100)); font.bold: true; color: Theme.text; Layout.fillWidth: true }
                            ActionButton { text: "Otwórz →"; compact: true; primary: false; onClicked: page.openShopping() }
                        }
                        Repeater { model: Math.min(backend.shoppingItems.length, 6)
                            delegate: ShoppingRow { Layout.fillWidth: true; item: backend.shoppingItems[index];
                                onCheckRequested: backend.setShoppingDone(itemId, bought) }
                        }
                        Text { text: backend.dashboard.shopping + " rzeczy do kupienia";
                            font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); color: Theme.muted }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; visible: page.overdue.length > 0;
                Layout.preferredHeight: overdueContent.implicitHeight + 38;
                color: Theme.warningSoft; border.color: Theme.border; radius: 16
                ColumnLayout { id: overdueContent; anchors.fill: parent; anchors.margins: 18; spacing: 9
                    RowLayout { Layout.fillWidth: true
                        Text { text: "Zaległe zadania — wybierz, co przenieść";
                            color: Theme.warning; font.bold: true; font.pixelSize: Math.max(11, Math.round(17 * backend.fontScale / 100)); Layout.fillWidth: true }
                        ActionButton { text: "Przenieś zaznaczone na dziś"; compact: true;
                            enabled: page.selectedOverdue.length > 0; onClicked: {
                                if (backend.moveOverdueSelection(page.selectedOverdue, backend.today))
                                    page.selectedOverdue = []
                            } }
                    }
                    Repeater { model: page.overdue
                        delegate: CheckBox { Layout.fillWidth: true
                            text: modelData.startDate + " · " + modelData.title + " · " + (modelData.memberName || "Wszyscy")
                            font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100)); checked: page.selectedOverdue.indexOf(modelData.id) >= 0
                            onToggled: {
                                var a = page.selectedOverdue.slice(); var i = a.indexOf(modelData.id)
                                if (checked && i < 0) a.push(modelData.id)
                                else if (!checked && i >= 0) a.splice(i,1)
                                page.selectedOverdue = a
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: notesColumn.implicitHeight + 30;
                radius: 16; color: Theme.surface; border.color: Theme.border
                ColumnLayout { id: notesColumn; anchors.fill: parent; anchors.margins: 15; spacing: 7
                    Text { text: "Notatki dla domowników"; color: Theme.text; font.pixelSize: Math.max(11, Math.round(18 * backend.fontScale / 100)); font.bold: true }
                    RowLayout { Layout.fillWidth: true
                        FormInput { id: noteInput; Layout.fillWidth: true; placeholderText: "Zostaw krótką wiadomość..."; maximumLength: 600 }
                        ActionButton { text: "Dodaj"; compact: true; onClicked: {
                            if (backend.addNote(noteInput.text)) noteInput.clear()
                        } }
                    }
                    Repeater { model: page.notesList
                        delegate: RowLayout { Layout.fillWidth: true; spacing: 8
                            Text { text: "• " + modelData.text; color: Theme.text; font.pixelSize: Math.max(11, Math.round(14 * backend.fontScale / 100));
                                Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            ActionButton { text: "×"; compact: true; danger: true; primary: false;
                                onClicked: backend.removeNote(modelData.id) }
                        }
                    }
                }
            }
            Text { text: page.statusMessage; visible: page.statusMessage.length > 0; color: Theme.accent;
                font.pixelSize: Math.max(11, Math.round(13 * backend.fontScale / 100)); Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }
    }
    QuickTaskPopup { id: quickPopup }
    TaskEditor { id: taskEditor; onSaved: page.statusMessage = "Zapisano zadanie." }
    TaskActions { id: taskActions
        onEditRequested: { taskEditor.taskId = taskId; taskEditor.open() }
        onSubtasksRequested: { subtasks.taskId=taskId; subtasks.date=day; subtasks.open() }
        onAssignmentRequested: { assignment.taskId = taskId; assignment.taskTitle = taskActions.task.title;
            assignment.currentMemberId = taskActions.task.memberId; assignment.open() }
        onSuccess: page.statusMessage = message
    }
    AssignmentDialog { id: assignment }
    SubtasksDialog { id: subtasks }
    CopyDayDialog { id: copyDayDialog; onCopied: page.statusMessage = message }
    DayTemplatesDialog { id: dayTemplatesDialog }
    function selectedAssignee() {
        var choices = backend.assignees
        return assigneeBox.currentIndex >= 0 && assigneeBox.currentIndex < choices.length
            ? choices[assigneeBox.currentIndex].id : -1
    }
    function addCustom() {
        if (backend.addTask(quickInput.text, backend.today, "once", 0, selectedAssignee())) {
            quickInput.clear(); page.statusMessage = "Zadanie dodane."
        }
    }
    function newTask() { taskEditor.taskId = -1; taskEditor.initialDate = backend.today; taskEditor.open() }
    function openQuickTask() { quickPopup.targetDate = backend.today; quickPopup.selectedMemberId = selectedAssignee(); quickPopup.open() }
    function editAssignee(task) { assignment.taskId = task.id; assignment.taskTitle = task.title;
        assignment.currentMemberId = task.memberId; assignment.open() }
    function openActions(task) { taskActions.task = task; taskActions.day = backend.today; taskActions.open() }
}
