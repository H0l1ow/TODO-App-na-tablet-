import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import "../components"

// Portrait-first home screen: one primary action, one readable task list.
// Planning, overdue management and notes are moved into secondary dialogs.
Item {
    id: page
    signal openShopping()
    property int memberFilter: -2
    property var tasks: backend.tasksForDateFiltered(backend.today, memberFilter)
    property var pendingTasks: tasks.filter(function(t) { return !t.done && !t.skipped })
    property var finishedTasks: tasks.filter(function(t) { return !!t.done || !!t.skipped })
    property var overdue: backend.overdueTasks()
    property var selectedOverdue: []
    property var notesList: backend.notes()
    property bool completedExpanded: false
    property string statusMessage: ""
    readonly property real gutter: Math.max(14, Math.min(24, width * 0.035))

    Connections {
        target: backend
        function onDataChanged() {
            page.overdue = backend.overdueTasks()
            page.notesList = backend.notes()
            var available = page.overdue.map(function(t) { return t.id })
            page.selectedOverdue = page.selectedOverdue.filter(function(id) { return available.indexOf(id) >= 0 })
        }
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: body.implicitHeight + 2 * page.gutter
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            x: page.gutter
            y: page.gutter
            width: Math.max(0, scroll.width - 2 * page.gutter)
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { text: "Dzisiaj"; color: Theme.text; font.bold: true; font.pixelSize: 27 }
                    Text { text: backend.todayLabel; color: Theme.muted; font.pixelSize: 13;
                        Layout.fillWidth: true; wrapMode: Text.WordWrap }
                }
                ColumnLayout {
                    spacing: 2
                    Text { text: backend.dashboard.done + " / " + backend.dashboard.total;
                        color: Theme.accent; font.pixelSize: 20; font.bold: true;
                        Layout.alignment: Qt.AlignRight }
                    Text { text: "wykonane"; color: Theme.muted; font.pixelSize: 12;
                        Layout.alignment: Qt.AlignRight }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.surfaceMuted
                Rectangle {
                    width: backend.dashboard.total ? parent.width * backend.dashboard.done / backend.dashboard.total : 0
                    height: parent.height
                    radius: 3
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                ActionButton {
                    text: "+ Szybkie zadanie"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    onClicked: openQuickTask()
                }
                ActionButton {
                    text: "Wpisz"
                    primary: false
                    Layout.preferredHeight: 54
                    Layout.preferredWidth: 100
                    onClicked: newTask()
                }
            }

            Rectangle {
                visible: page.overdue.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? overdueBanner.implicitHeight + 24 : 0
                color: Theme.warningSoft
                radius: 12
                RowLayout {
                    id: overdueBanner
                    anchors.fill: parent
                    anchors.leftMargin: 13
                    anchors.rightMargin: 13
                    spacing: 10
                    Text {
                        text: "Zaleg\u0142e: " + page.overdue.length
                        color: Theme.warning
                        font.bold: true
                        font.pixelSize: 14
                        Layout.fillWidth: true
                    }
                    ActionButton { text: "Przejrzyj"; primary: false; compact: true;
                        onClicked: overdueDialog.open() }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: taskCard.implicitHeight + 32
                radius: 14
                color: Theme.surface
                border.color: Theme.border
                ColumnLayout {
                    id: taskCard
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 15
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: "Do zrobienia (" + page.pendingTasks.length + ")"
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.text
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        ComboBox {
                            id: memberChoice
                            Layout.preferredWidth: Math.min(156, Math.max(122, taskCard.width * 0.37))
                            Layout.preferredHeight: 43
                            model: [{"id":-2,"name":"Wszystkie"}].concat(backend.assignees)
                            textRole: "name"
                            onCurrentIndexChanged: {
                                var choices = [{"id":-2,"name":"Wszystkie"}].concat(backend.assignees)
                                page.memberFilter = currentIndex >= 0 && currentIndex < choices.length ? choices[currentIndex].id : -2
                            }
                        }
                    }
                    Text {
                        visible: page.tasks.length === 0
                        text: "Brak zada\u0144 na dzi\u015b. Dodaj pierwsze szybkim przyciskiem powy\u017cej."
                        color: Theme.muted
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.bottomMargin: 12
                    }
                    Text {
                        visible: page.tasks.length > 0 && page.pendingTasks.length === 0
                        text: "Na teraz wszystko gotowe."
                        color: Theme.accent
                        font.pixelSize: 15
                        Layout.fillWidth: true
                        Layout.topMargin: 9
                        Layout.bottomMargin: 9
                    }
                    Repeater {
                        model: page.pendingTasks
                        delegate: TaskRow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            task: modelData
                            onCheckRequested: backend.setTaskDone(taskId, backend.today, done)
                            onAssigneeRequested: page.editAssignee(task)
                            onActionRequested: page.openActions(task)
                        }
                    }
                    Button {
                        id: finishedButton
                        visible: page.finishedTasks.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 46 : 0
                        background: Rectangle { color: finishedButton.down ? Theme.accentSoft : Theme.surfaceMuted; radius: 10 }
                        contentItem: Text {
                            text: (page.completedExpanded ? "Ukryj" : "Poka\u017c") + " wykonane (" + page.finishedTasks.length + ")"
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.muted
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                        }
                        onClicked: page.completedExpanded = !page.completedExpanded
                    }
                    Repeater {
                        model: page.completedExpanded ? page.finishedTasks : []
                        delegate: TaskRow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            task: modelData
                            onCheckRequested: backend.setTaskDone(taskId, backend.today, done)
                            onAssigneeRequested: page.editAssignee(task)
                            onActionRequested: page.openActions(task)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ActionButton {
                    Layout.fillWidth: true
                    text: "Opcje dnia"
                    primary: false
                    onClicked: dayOptions.open()
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: "Zakupy (" + backend.dashboard.shopping + ")"
                    primary: false
                    onClicked: page.openShopping()
                }
            }
            Text {
                text: page.statusMessage
                visible: page.statusMessage.length > 0
                Layout.fillWidth: true
                color: Theme.accent
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }

    QuickTaskPopup { id: quickPopup }
    TaskEditor { id: taskEditor; onSaved: page.statusMessage = "Zapisano zadanie." }
    TaskActions {
        id: taskActions
        onEditRequested: { taskEditor.taskId = taskId; taskEditor.open() }
        onSubtasksRequested: { subtasks.taskId = taskId; subtasks.date = day; subtasks.open() }
        onAssignmentRequested: {
            assignment.taskId = taskId
            assignment.taskTitle = taskActions.task.title
            assignment.currentMemberId = taskActions.task.memberId
            assignment.open()
        }
        onSuccess: page.statusMessage = message
    }
    AssignmentDialog { id: assignment }
    SubtasksDialog { id: subtasks }
    CopyDayDialog { id: copyDayDialog; onCopied: page.statusMessage = message }
    DayTemplatesDialog { id: dayTemplatesDialog }

    Dialog {
        id: dayOptions
        title: "Opcje dnia"
        modal: true; focus: true
        standardButtons: Dialog.NoButton
        width: Math.min(420, page.width - 24)
        x: (page.width - width) / 2
        y: (page.height - height) / 2
        padding: 15
        background: Rectangle { color: Theme.surface; radius: 14; border.color: Theme.border }
        contentItem: ColumnLayout {
            spacing: 10
            ActionButton { Layout.fillWidth: true; text: "Kopiuj ca\u0142y dzie\u0144";
                onClicked: { dayOptions.close(); copyDayDialog.sourceDate = backend.today; copyDayDialog.open() } }
            ActionButton { Layout.fillWidth: true; text: "Szablony dni"; primary: false;
                onClicked: { dayOptions.close(); dayTemplatesDialog.targetDate = backend.today; dayTemplatesDialog.open() } }
            ActionButton { Layout.fillWidth: true; text: "Notatki domowe"; primary: false;
                onClicked: { dayOptions.close(); notesDialog.open() } }
            ActionButton { Layout.fillWidth: true; text: "Cofnij ostatni\u0105 operacj\u0119";
                primary: false; enabled: backend.undoLabel.length > 0; onClicked: { backend.undoLast(); dayOptions.close() } }
            ActionButton { Layout.fillWidth: true; text: "Zamknij"; primary: false; onClicked: dayOptions.close() }
        }
    }

    Dialog {
        id: overdueDialog
        title: "Zaleg\u0142e zadania"
        modal: true
        width: Math.min(470, page.width - 24)
        height: Math.min(560, page.height - 42)
        x: (page.width - width)/2
        y: (page.height - height)/2
        standardButtons: Dialog.NoButton
        background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: 14 }
        onOpened: page.selectedOverdue = []
        contentItem: ColumnLayout {
            spacing: 10
            Text { Layout.fillWidth: true; text: "Zaznacz, co przenie\u015b\u0107 na dzisiaj.";
                color: Theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                ColumnLayout {
                    width: Math.max(0, overdueDialog.width - 36)
                    spacing: 7
                    Repeater {
                        model: page.overdue
                        delegate: CheckBox {
                            Layout.fillWidth: true
                            text: modelData.title + " (" + modelData.startDate + ")"
                            font.pixelSize: 14
                            checked: page.selectedOverdue.indexOf(modelData.id) >= 0
                            onToggled: {
                                var ids = page.selectedOverdue.slice()
                                var i = ids.indexOf(modelData.id)
                                if (checked && i < 0) ids.push(modelData.id)
                                else if (!checked && i >= 0) ids.splice(i, 1)
                                page.selectedOverdue = ids
                            }
                        }
                    }
                }
            }
            ActionButton { Layout.fillWidth: true; text: "Przenie\u015b zaznaczone";
                enabled: page.selectedOverdue.length > 0
                onClicked: { if (backend.moveOverdueSelection(page.selectedOverdue, backend.today)) overdueDialog.close() } }
            ActionButton { Layout.fillWidth: true; text: "Anuluj"; primary: false; onClicked: overdueDialog.close() }
        }
    }

    Dialog {
        id: notesDialog
        title: "Notatki domowe"
        modal: true
        width: Math.min(470, page.width - 24)
        height: Math.min(530, page.height - 42)
        x: (page.width - width)/2
        y: (page.height - height)/2
        standardButtons: Dialog.NoButton
        background: Rectangle { color: Theme.surface; border.color: Theme.border; radius: 14 }
        contentItem: ColumnLayout {
            spacing: 10
            FormInput { id: noteInput; Layout.fillWidth: true; placeholderText: "Dodaj notatk\u0119...";
                maximumLength: 600 }
            ActionButton { text: "Dodaj notatk\u0119"; Layout.fillWidth: true;
                onClicked: { if (backend.addNote(noteInput.text)) noteInput.clear() } }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                ColumnLayout {
                    width: Math.max(0, notesDialog.width - 36)
                    spacing: 9
                    Repeater {
                        model: page.notesList
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Text { text: modelData.text; Layout.fillWidth: true; wrapMode: Text.WordWrap;
                                color: Theme.text; font.pixelSize: 14 }
                            ActionButton { text: "Usu\u0144"; primary: false; danger: true; compact: true;
                                onClicked: backend.removeNote(modelData.id) }
                        }
                    }
                }
            }
            ActionButton { Layout.fillWidth: true; text: "Gotowe"; primary: false; onClicked: notesDialog.close() }
        }
    }

    function newTask() { taskEditor.taskId = -1; taskEditor.initialDate = backend.today; taskEditor.open() }
    function openQuickTask() { quickPopup.targetDate = backend.today; quickPopup.selectedMemberId = -1; quickPopup.open() }
    function editAssignee(task) { assignment.taskId = task.id; assignment.taskTitle = task.title;
        assignment.currentMemberId = task.memberId; assignment.open() }
    function openActions(task) { taskActions.task = task; taskActions.day = backend.today; taskActions.open() }
}
